import AppKit
import ApplicationServices
import ImageIO
import UniformTypeIdentifiers

enum Failure:Error {case message(String)}
@main enum Recorder {
 @MainActor static func main() {
  let app=NSApplication.shared
  let runner=Runner()
  Task {do {try await runner.run();exit(0)}catch{try? String(describing:error).write(to:runner.dir.appendingPathComponent("failure.txt"),atomically:true,encoding:.utf8);exit(1)}}
  app.run()
 }
}
@MainActor final class Runner {
 let dir=URL(fileURLWithPath:CommandLine.arguments[2])
 let appURL=URL(fileURLWithPath:CommandLine.arguments[1])
 var targetPID:pid_t=0;var common:Process!;var start=Date();var events:[[String:Any]]=[]
 let code="""
# Build a dated checksum report for this project
project_dir="$HOME/Projects/commoncopy-demo"
report_dir="$project_dir/reports/$(date +%Y-%m-%d)"
mkdir -p "$report_dir"

find "$project_dir" -type f \\
  ! -path '*/.git/*' ! -path '*/reports/*' \\
  -print0 |
while IFS= read -r -d '' file; do
  shasum -a 256 "$file"
done > "$report_dir/checksums.sha256"

{
  printf 'Project: %s\\n' "$project_dir"
  printf 'Generated: %s\\n' "$(date)"
  printf 'Files indexed: %s\\n' \\
    "$(wc -l < "$report_dir/checksums.sha256" | tr -d ' ')"
} > "$report_dir/summary.txt"
"""
 let prompt="Turn the notes below into a clear project brief. Include the goal, intended audience, deliverables, and three practical next steps.\n\nNotes: [paste your notes here]"
 let webText="A clear project brief sets out the goal, audience, deliverables, and next steps."
 var recording=false
 var frames=0
 func pause(_ s:Double) async {try? await Task.sleep(nanoseconds:UInt64(s*1e9))}
 func mark(_ name:String){events.append(["seconds":Date().timeIntervalSince(start),"action":name]);writeJSON(events,"events.json")}
 func writeJSON(_ data:Any,_ name:String){if let d=try? JSONSerialization.data(withJSONObject:data,options:.prettyPrinted){try? d.write(to:dir.appendingPathComponent(name))}}
 func bridge(_ operation:String,_ fields:[String:Any]=[:]) throws->[String:Any] {
  var request=fields;request["operation"]=operation
  let p=Process();p.executableURL=appURL.appendingPathComponent("Contents/Helpers/Core/CommonCopy.DesktopBridge")
  p.arguments=[NSHomeDirectory()+"/Library/Application Support/CommonCopy"];let input=Pipe(),output=Pipe();p.standardInput=input;p.standardOutput=output;p.standardError=FileHandle.nullDevice
  try p.run();try input.fileHandleForWriting.write(contentsOf:JSONSerialization.data(withJSONObject:request));try input.fileHandleForWriting.close()
  let data=output.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit()
  let j=try JSONSerialization.jsonObject(with:data)as! [String:Any]
  guard j["ok"]as? Bool == true else{throw Failure.message("Core operation failed: "+operation)}
  return j["state"]as! [String:Any]
 }
 func process(_ exe:URL,_ args:[String]=[]) throws->Process{let p=Process();p.executableURL=exe;p.arguments=args;p.standardOutput=FileHandle.nullDevice;p.standardError=FileHandle.nullDevice;try p.run();return p}
 func command(_ s:String) throws{try s.write(to:dir.appendingPathComponent("command.txt"),atomically:true,encoding:.utf8)}
 func key(_ code:CGKeyCode,_ flags:CGEventFlags=[]) async {
  let d=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:true)!,u=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:false)!;d.flags=flags;u.flags=flags;d.post(tap:.cghidEventTap);u.post(tap:.cghidEventTap);await pause(0.18)
 }
 func attr(_ element:AXUIElement,_ name:String)->CFTypeRef?{var out:CFTypeRef?;AXUIElementCopyAttributeValue(element,name as CFString,&out);return out}
 func find(_ el:AXUIElement,role:String?=nil,title:String?=nil,depth:Int=0)->AXUIElement?{
  if depth>35{return nil}
  let r=attr(el,kAXRoleAttribute)as? String
  let t=(attr(el,kAXTitleAttribute)as? String) ?? (attr(el,kAXDescriptionAttribute)as? String)
  if (role==nil || r==role) && (title==nil || t==title){return el}
  for child in (attr(el,kAXChildrenAttribute)as? [AXUIElement] ?? []){if let found=find(child,role:role,title:title,depth:depth+1){return found}}
  return nil
 }
 func press(_ el:AXUIElement)throws{guard AXUIElementPerformAction(el,kAXPressAction as CFString) == .success else{throw Failure.message("Could not press native control")}}
 var ax:AXUIElement{AXUIElementCreateApplication(common.processIdentifier)}
 func check(_ ok:Bool,_ message:String)throws{if !ok{throw Failure.message(message)}}
 func menu() async {
  NSRunningApplication(processIdentifier:targetPID)?.activate(options:.activateIgnoringOtherApps)
  await pause(0.4);CGWarpMouseCursorPosition(CGPoint(x:350,y:240))
  let p=CGPoint(x:350,y:240)
  let d=CGEvent(mouseEventSource:nil,mouseType:.rightMouseDown,mouseCursorPosition:p,mouseButton:.right)!
  let u=CGEvent(mouseEventSource:nil,mouseType:.rightMouseUp,mouseCursorPosition:p,mouseButton:.right)!
  d.flags = .maskCommand;u.flags = .maskCommand;d.post(tap:.cghidEventTap);u.post(tap:.cghidEventTap)
  await pause(1.0)
 }
 func choose(_ group:String,_ title:String)async throws{
  let downCount=group=="Code" ? 4 : 3
  for _ in 0..<downCount{await key(125)}
  await key(124);await pause(0.8)
  await key(125)
  if group=="GPT"{await key(124);await pause(0.8)}
  mark(group+" native submenu visible");await pause(0.8);await key(36)
 }
 var screenFrames:ScreenFrames?
 func beginCapture(){start=Date();let f=ScreenFrames(dir:dir);screenFrames=f;f.start()}

 func click(_ p:CGPoint,count:Int64=1) async{
  CGWarpMouseCursorPosition(p)
  let down=CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:p,mouseButton:.left)!
  let up=CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:p,mouseButton:.left)!
  down.setIntegerValueField(.mouseEventClickState,value:count);up.setIntegerValueField(.mouseEventClickState,value:count)
  down.post(tap:.cghidEventTap);up.post(tap:.cghidEventTap);await pause(0.4)
 }
 func openApp(_ name:String,_ document:String?=nil)async throws{
  var args=["-a",name];if let document{args.append(document)}
  let p=try process(URL(fileURLWithPath:"/usr/bin/open"),args);p.waitUntilExit();await pause(1.5)
  let bundle=name=="Terminal" ? "com.apple.Terminal":"com.apple.Safari"
  guard let app=NSRunningApplication.runningApplications(withBundleIdentifier:bundle).first else{throw Failure.message("Destination app did not open")}
  targetPID=app.processIdentifier;app.activate(options:.activateIgnoringOtherApps);await pause(0.5)
 }
 func fitWindow()throws{
  let targetAX=AXUIElementCreateApplication(targetPID)
  guard let window=(attr(targetAX,kAXWindowsAttribute)as? [AXUIElement])?.first else{throw Failure.message("Missing destination window")}
  var point=CGPoint(x:0,y:25),size=CGSize(width:1024,height:680)
  AXUIElementSetAttributeValue(window,kAXPositionAttribute as CFString,AXValueCreate(.cgPoint,&point)!)
  AXUIElementSetAttributeValue(window,kAXSizeAttribute as CFString,AXValueCreate(.cgSize,&size)!)
 }
 func type(_ value:String)async{
  NSPasteboard.general.clearContents();NSPasteboard.general.setString(value,forType:.string);await key(9,.maskCommand);await pause(0.3)
 }
 func findText(_ el:AXUIElement,_ text:String,depth:Int=0)->AXUIElement?{
  if depth>35{return nil}
  if let s=(attr(el,kAXValueAttribute)as? String) ?? (attr(el,kAXTitleAttribute)as? String),s.contains(text){return el}
  for c in (attr(el,kAXChildrenAttribute)as? [AXUIElement] ?? []){if let found=findText(c,text,depth:depth+1){return found}};return nil
 }
 func point(_ el:AXUIElement)throws->CGPoint{
  var p=CGPoint.zero
  guard let v=attr(el,kAXPositionAttribute),CFGetTypeID(v)==AXValueGetTypeID(),AXValueGetValue(unsafeBitCast(v,to:AXValue.self),.cgPoint,&p)else{throw Failure.message("No accessible text position")};return p
 }
 func run()async throws{
  try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
  try check(ProcessInfo.processInfo.environment["GITHUB_ACTIONS"]=="true","Disposable CI only")
  try check(AXIsProcessTrusted() && CGPreflightScreenCaptureAccess(),"Native capture permission unavailable")
  let state=try bridge("snapshot");let cats=(state["document"]as! [String:Any])["categories"]as! [[String:Any]]
  let codeID=cats.first{$0["name"]as? String=="Code"}!["id"]as! String
  let dayID=cats.first{$0["name"]as? String=="Day-to-Day"}!["id"]as! String
  let promptsID=cats.first{$0["name"]as? String=="Prompts"}!["id"]as! String
  _=try bridge("saveCategory",["name":"GPT","parentId":promptsID])
  let next=try bridge("snapshot");let list=(next["document"]as! [String:Any])["categories"]as! [[String:Any]]
  let gptID=list.first{$0["name"]as? String=="GPT"}!["id"]as! String
  _=try bridge("savePhrase",["categoryId":codeID,"title":"Project checksum report","text":code,"isEnabled":true,"isFavorite":true])
  _=try bridge("savePhrase",["categoryId":gptID,"title":"Draft a project brief","text":prompt,"isEnabled":true,"isFavorite":false])
  common=try process(appURL.appendingPathComponent("Contents/MacOS/CommonCopyMac"))
  defer{common.terminate()}
  await pause(3)
  try await openApp("Terminal");try fitWindow()
  await type("exec /bin/zsh -l");await key(36);await pause(0.8)
  await type("PS1='project % '; clear");await key(36);await pause(0.7)
  for _ in 0..<3{await key(24,[.maskCommand,.maskShift])}
  try fitWindow();await pause(0.5)
  beginCapture();mark("actual Terminal ready");await pause(1)
  await menu();mark("Terminal CommonCopy menu")
  try await choose("Code","Project checksum report");await pause(1.5)
  await key(124);await pause(0.3)
  let terminalAX=AXUIElementCreateApplication(targetPID)
  try check(findText(terminalAX,"Build a dated checksum report") != nil,"Code was not visible in actual Terminal")
  try check(!FileManager.default.fileExists(atPath:NSHomeDirectory()+"/Projects/commoncopy-demo/reports"),"Demo script unexpectedly executed")
  mark("actual Terminal code pasted without execution");await pause(2.5)
  try await openApp("Safari","https://chatgpt.com/");try fitWindow();await pause(18)
  await click(CGPoint(x:972,y:165));await pause(0.5)
  let safariAX=AXUIElementCreateApplication(targetPID)
  guard let composer=find(safariAX,role:kAXTextAreaRole)else{throw Failure.message("Actual ChatGPT composer unavailable")}
  AXUIElementSetAttributeValue(composer,kAXFocusedAttribute as CFString,kCFBooleanTrue)
  await pause(0.5);mark("actual ChatGPT composer ready");await pause(0.7)
  await menu();try await choose("GPT","Draft a project brief");await pause(1.7)
  await key(0,.maskCommand);await key(8,.maskCommand);await pause(0.3)
  try check(NSPasteboard.general.string(forType:.string)?.contains(prompt)==true,"Prompt was not pasted into actual ChatGPT composer")
  await key(124);mark("actual ChatGPT prompt pasted unsent");await pause(2)
  let emailPath=URL(fileURLWithPath:CommandLine.arguments[3]).path
  try await openApp("Safari",emailPath);try fitWindow();await pause(2)
  let emailText="Thanks for the thoughtful feedback. I have updated the project brief and the revised timeline is ready for your review."
  guard let paragraph=findText(safariAX,emailText)else{throw Failure.message("Sample email paragraph unavailable")}
  let pos=try point(paragraph)
  mark("sample email in actual Safari window");await pause(1)
  await click(CGPoint(x:pos.x+40,y:pos.y+12),count:3);await pause(0.6)
  await key(8,.maskCommand);await pause(0.3)
  try check(NSPasteboard.general.string(forType:.string)?.trimmingCharacters(in:.whitespacesAndNewlines)==emailText,"Email paragraph selection differs")
  mark("email paragraph highlighted");await pause(0.6)
  await menu();await key(36);await pause(2)
  guard let sheet=find(ax,role:kAXSheetRole)else{throw Failure.message("Native capture sheet unavailable")}
  if let title=find(sheet,role:kAXTextFieldRole){AXUIElementSetAttributeValue(title,kAXValueAttribute as CFString,"Project handoff reply"as CFString)}
  guard let picker=find(sheet,role:kAXPopUpButtonRole)else{throw Failure.message("Category picker unavailable")}
  try press(picker);await pause(0.3);await key(119);await key(36);await pause(0.6)
  mark("email capture categorized Day-to-Day");await pause(1.5)
  guard let save=find(ax,role:kAXButtonRole,title:"Save")else{throw Failure.message("Save unavailable")}
  try press(save);await pause(1.5)
  let final=try bridge("snapshot");let phrases=(final["document"]as! [String:Any])["phrases"]as! [[String:Any]]
  try check(phrases.contains{($0["text"]as? String)?.trimmingCharacters(in:.whitespacesAndNewlines)==emailText && $0["categoryId"]as? String==dayID},"Email was not saved under Day-to-Day")
  mark("email saved to Day-to-Day and editor dismissed");await pause(1.8)
  screenFrames?.running=false;await pause(0.6)
  writeJSON(["platform":"macOS","realTerminalPasteVerified":true,"terminalScriptUnexecuted":true,"realChatGPTComposerPasteVerified":true,"promptUnsent":true,"simulatedEmailInSafari":true,"emailCategoryVerified":"Day-to-Day","events":events],"workflow.json")
 }

}

final class ScreenFrames: @unchecked Sendable {
 let dir:URL;var running=true
 init(dir:URL){self.dir=dir}
 func start(){
  Thread.detachNewThread{[self] in
   let began=Date();var n=0
   while running{
    let url=dir.appendingPathComponent(String(format:"frame-%05d.jpg",n))
    let shot=Process();shot.executableURL=URL(fileURLWithPath:"/usr/sbin/screencapture");shot.arguments=["-x","-C","-t","jpg",url.path];shot.standardError=FileHandle.nullDevice
    do{try shot.run();shot.waitUntilExit();if shot.terminationStatus==0{n+=1}else{break}}catch{break}
    let remaining=Double(n)*0.1-Date().timeIntervalSince(began);if remaining>0{Thread.sleep(forTimeInterval:remaining)}
   }
   let j:[String:Any]=["frames":n,"elapsedSeconds":Date().timeIntervalSince(began)]
   if let data=try? JSONSerialization.data(withJSONObject:j){try? data.write(to:dir.appendingPathComponent("capture.json"))}
  }
 }
}
