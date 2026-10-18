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
 var target:Process!;var common:Process!;var start=Date();var events:[[String:Any]]=[]
 let code="pwd\nls -la\nprintf 'Ready to build\\n'"
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
  if depth>16{return nil}
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
  NSRunningApplication(processIdentifier:target.processIdentifier)?.activate(options:.activateIgnoringOtherApps)
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
 func run()async throws{
  try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
  try check(ProcessInfo.processInfo.environment["GITHUB_ACTIONS"]=="true","Disposable CI only")
  try check(AXIsProcessTrusted() && CGPreflightScreenCaptureAccess(),"Native capture permission unavailable")
  let state=try bridge("snapshot");let doc=state["document"]as! [String:Any];let cats=doc["categories"]as! [[String:Any]]
  let codeID=cats.first{$0["name"]as? String=="Code"}!["id"]as! String
  let promptsID=cats.first{$0["name"]as? String=="Prompts"}!["id"]as! String
  _=try bridge("saveCategory",["name":"GPT","parentId":promptsID])
  let next=try bridge("snapshot");let list=(next["document"]as! [String:Any])["categories"]as! [[String:Any]]
  let gptID=list.first{$0["name"]as? String=="GPT"}!["id"]as! String
  _=try bridge("savePhrase",["categoryId":codeID,"title":"Inspect project files","text":code,"isEnabled":true,"isFavorite":true])
  _=try bridge("savePhrase",["categoryId":gptID,"title":"Draft a project brief","text":prompt,"isEnabled":true,"isFavorite":false])
  common=try process(appURL.appendingPathComponent("Contents/MacOS/CommonCopyMac"))
  defer {common.terminate();target?.terminate()}
  await pause(3)
  target=try process(URL(fileURLWithPath:CommandLine.arguments[3]),[dir.path]);await pause(2)
  try command("text:Terminal snippet · ready to paste\n\n");await pause(0.8)
  beginCapture();mark("Mac shell example ready");await pause(0.8)
  await menu();mark("native macOS phrase menu")
  try await choose("Code","Inspect project files");await pause(1.5)
  let pasted=try String(contentsOf:dir.appendingPathComponent("editor.txt"),encoding:.utf8)
  try check(pasted.contains(code),"Mac shell snippet was not pasted")
  mark("Mac shell snippet pasted");await pause(1.5)
  try command("text:GPT prompt · ready to paste\n\n");await pause(1)
  mark("GPT example ready");await menu()
  try await choose("GPT","Draft a project brief");await pause(1.5)
  let promptPasted=try String(contentsOf:dir.appendingPathComponent("editor.txt"),encoding:.utf8)
  try check(promptPasted.contains(prompt),"GPT prompt was not pasted")
  mark("GPT prompt pasted");await pause(1.5)
  try command("web");await pause(3);mark("webpage visible")
  try command("select-web");await pause(1);mark("webpage text highlighted")
  await menu()
  await key(36);await pause(2)
  if let sheet=find(ax,role:kAXSheetRole),let title=find(sheet,role:kAXTextFieldRole){AXUIElementSetAttributeValue(title,kAXValueAttribute as CFString,"Project brief checklist"as CFString)}
  mark("native macOS capture sheet");await pause(1.3)
  guard let saveButton=find(ax,role:kAXButtonRole,title:"Save")else{throw Failure.message("Missing Save button")}
  try press(saveButton);await pause(1.5)
  let final=try bridge("snapshot");let phrases=(final["document"]as! [String:Any])["phrases"]as! [[String:Any]]
  try check(phrases.contains{($0["text"]as? String)?.trimmingCharacters(in:.whitespacesAndNewlines)==webText},"Webpage text was not saved")
  mark("webpage saved and editor dismissed");await pause(1.5)
  screenFrames?.running=false;await pause(0.5)
  writeJSON(["platform":"macOS","realCodePasteVerified":true,"realPromptPasteVerified":true,"realWebCaptureVerified":true,"events":events],"workflow.json")
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
