import AppKit
let output=CommandLine.arguments[1]
func run(_ source:String)->String{
 var error:NSDictionary?
 let result=NSAppleScript(source:source)?.executeAndReturnError(&error)
 return error.map{String(describing:$0)} ?? result?.stringValue ?? "ok"
}
func shot(_ name:String){
 let p=Process();p.executableURL=URL(fileURLWithPath:"/usr/sbin/screencapture");p.arguments=["-x",output+"/"+name+".png"];try? p.run();p.waitUntilExit()
}
try FileManager.default.createDirectory(atPath:output,withIntermediateDirectories:true)
var notes:[String:String]=[:]
notes["terminal"]=run("""
tell application "Terminal"
 activate
 do script "clear"
 set bounds of front window to {0, 25, 1024, 706}
 set current settings of front window to settings set "Basic"
end tell
""")
Thread.sleep(forTimeInterval:2);shot("terminal")
notes["mail"]=run("""
tell application "Mail"
 activate
 set m to make new outgoing message with properties {subject:"Sample email — project handoff",content:"Hi Alex,\n\nThanks for the thoughtful feedback. I have updated the project brief and attached the revised timeline for your review.\n\nPlease send any final notes by Thursday so we can confirm the next steps.\n\nBest,\nJordan",visible:true}
end tell
""")
Thread.sleep(forTimeInterval:4);shot("mail")
notes["chatgpt"]=run("""
tell application "Safari"
 activate
 make new document with properties {URL:"https://chatgpt.com/"}
 set bounds of front window to {0, 25, 1024, 706}
end tell
""")
Thread.sleep(forTimeInterval:15);shot("chatgpt")
notes["safariText"]=run("""
tell application "Safari" to get name of front document
""")
let data=try JSONSerialization.data(withJSONObject:notes,options:.prettyPrinted);try data.write(to:URL(fileURLWithPath:output+"/probe.json"))
