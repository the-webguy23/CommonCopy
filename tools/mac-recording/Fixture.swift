import AppKit
import WebKit

@main enum Fixture {
 @MainActor static func main() {
  let app = NSApplication.shared
  let d = Delegate()
  app.delegate=d;app.run();withExtendedLifetime(d){}
 }
}
@MainActor final class Delegate:NSObject,NSApplicationDelegate,NSTextViewDelegate {
 let dir=URL(fileURLWithPath:CommandLine.arguments[1])
 var window:NSWindow!;var editor:NSTextView!;var web:WKWebView!;var last=""
 func applicationDidFinishLaunching(_ n:Notification) {
  NSApp.setActivationPolicy(.regular)
  let menu=NSMenu();let item=NSMenuItem();let edit=NSMenu(title:"Edit")
  for (name,action,key) in [("Copy","copy:","c"),("Paste","paste:","v"),("Select All","selectAll:","a")] {edit.addItem(withTitle:name,action:Selector(action),keyEquivalent:key)}
  item.submenu=edit;menu.addItem(item);NSApp.mainMenu=menu
  let rect=NSScreen.main!.visibleFrame
  window=NSWindow(contentRect:rect,styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
  window.title="CommonCopy examples";window.setFrame(rect,display:true)
  editor=NSTextView(frame:NSRect(origin:.zero,size:rect.size));editor.isRichText=false
  editor.font=NSFont.monospacedSystemFont(ofSize:22,weight:.regular);editor.textContainerInset=NSSize(width:40,height:45);editor.delegate=self
  window.contentView=editor;window.makeKeyAndOrderFront(nil);window.makeFirstResponder(editor)
  NSApp.activate(ignoringOtherApps:true);persist()
  Timer.scheduledTimer(withTimeInterval:0.1,repeats:true){[weak self] _ in MainActor.assumeIsolated {self?.poll()}}
 }
 func textDidChange(_ n:Notification){persist()}
 func persist(){try? editor.string.write(to:dir.appendingPathComponent("editor.txt"),atomically:true,encoding:.utf8)}
 func poll(){
  guard let c=try? String(contentsOf:dir.appendingPathComponent("command.txt"),encoding:.utf8),c != last else{return};last=c
  if c.hasPrefix("text:"){window.contentView=editor;editor.string=String(c.dropFirst(5));editor.setSelectedRange(NSRange(location:(editor.string as NSString).length,length:0));window.makeFirstResponder(editor);persist()}
  else if c=="web" {
   web=WKWebView(frame:window.contentView!.bounds)
   window.contentView=web;window.makeFirstResponder(web)
   let text="A clear project brief sets out the goal, audience, deliverables, and next steps."
   web.loadHTMLString("<html><head><style>body{font-family:-apple-system,Arial;color:#111;background:white;margin:50px 65px;line-height:1.7}nav{font-size:14px;border-bottom:1px solid #bbb;padding-bottom:20px}h1{font-size:34px;font-weight:500}p{font-size:21px;max-width:800px}small{color:#555}</style></head><body><nav>WORK NOTES / Planning</nav><h1>Start with a clear brief.</h1><p>Good work starts with a shared understanding of what needs to happen.</p><p id='excerpt'>"+text+"</p><p>Keep the essentials somewhere easy to find, and return to them as the project develops.</p><small>Local example article for the CommonCopy demonstration.</small></body></html>",baseURL:nil)
  }else if c=="select-web" {
   web.evaluateJavaScript("const r=document.createRange();r.selectNodeContents(document.getElementById('excerpt'));const s=window.getSelection();s.removeAllRanges();s.addRange(r);") {_,_ in}
  }
  NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil)
 }
}
