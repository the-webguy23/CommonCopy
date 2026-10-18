using System;
using System.IO;
using System.Linq;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Automation;
using System.Windows.Interop;
using System.Windows.Media;
using CommonCopy.Core.Models;
using CommonCopy.Core.Services;
using Forms = System.Windows.Forms;

internal static class Program
{
    const string Phrase = "@echo off\r\necho Project files\r\ndir /b";
    const string WebText = "A clear project brief sets out the goal, audience, deliverables, and next steps.";
    static WebBrowser? webpage;
    static bool webpageMode;
    static TextBlock heading = null!;
    static string output = "";
    static TextBox editor = null!;
    static Window source = null!;
    static Process commonCopy = null!;
    static int result = 1;
    static readonly System.Collections.Generic.List<object> events = new();
    static readonly Stopwatch clock = new();
    static bool capture;
    static Exception? captureError;
    [STAThread] static int Main(string[] args)
    {
        if (Environment.GetEnvironmentVariable("GITHUB_ACTIONS") != "true") return 2;
        output = Path.GetFullPath(args[1]); Directory.CreateDirectory(output);
        var app = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        editor = new TextBox { Text = Phrase, AcceptsReturn = true, TextWrapping = TextWrapping.Wrap,
            FontFamily = new FontFamily("Consolas"), FontSize = 22, Padding = new Thickness(36), BorderThickness = new Thickness(0), Background = Brushes.White };
        var root = new DockPanel();
        heading = new TextBlock { Text = "Batch snippet for Windows Terminal · plain text preview", FontSize = 16, Padding = new Thickness(24,16,24,16), Background = new SolidColorBrush(Color.FromRgb(245,245,245)) };
        DockPanel.SetDock(heading,Dock.Top);root.Children.Add(heading);root.Children.Add(editor);
        source = new Window { Title="CommonCopy examples — recording fixture", Width=980, Height=620, Left=20, Top=20, Content=root, WindowState=WindowState.Maximized, Background=Brushes.White };
        source.Loaded += async (_,_) => {
            try { await Record(args[0]); result=0; }
            catch(Exception error) { File.WriteAllText(Path.Combine(output,"failure.txt"),error.ToString()); }
            finally { capture=false; if(commonCopy is not null && !commonCopy.HasExited) commonCopy.Kill(true); app.Shutdown(); }
        };
        app.Run(source); return result;
    }
    static async Task Record(string exe)
    {
        // This is a disposable CI profile. Never run against a person's library.
        var path=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"CommonCopy");
        var prompts=new PhraseCategory { Name="Prompts" }; var gpt=new PhraseCategory { Name="GPT", ParentId=prompts.Id };
        var code=new PhraseCategory { Name="Code", SortOrder=1 };
        var research=new PhraseCategory { Name="Research", SortOrder=2 };
        var doc=new PhraseLibraryDocument();doc.Categories.AddRange(new[]{prompts,gpt,code,research});
        doc.Settings.StartWithWindows=false;
        var repo=new JsonPhraseRepository(path);await repo.SaveAsync(doc);
        commonCopy=Process.Start(new ProcessStartInfo(Path.GetFullPath(exe)) { WorkingDirectory=Path.GetDirectoryName(Path.GetFullPath(exe))! })!;
        await WaitWindow("CommonCopy"); await Task.Delay(900);
        // Close the manager through its normal system-menu Close action; the tray process continues.
        var manager=FindWindow(commonCopy.Id,null); var managerHandle=new IntPtr((int)manager.GetCurrentPropertyValue(AutomationElement.NativeWindowHandleProperty));
        PostMessage(managerHandle,0x0010,IntPtr.Zero,IntPtr.Zero);await Task.Delay(500);
        source.Activate(); editor.Focus(); await Task.Delay(400);
        capture=true;clock.Start();
        var recording=Task.Run(CaptureFrames);
        Mark("source text visible");await Task.Delay(700);
        editor.SelectAll(); Mark("real editable text selected");await Task.Delay(700);
        OpenMenu();await Task.Delay(900);Mark("native CommonCopy menu opened");
        Forms.SendKeys.SendWait("{DOWN}{ENTER}");
        var dialog=await WaitWindow("Save highlighted text"); Mark("real capture editor opened");await Task.Delay(600);
        var text=Child(dialog,"TextBox");
        if (((ValuePattern)text.GetCurrentPattern(ValuePattern.Pattern)).Current.Value != Phrase) throw new Exception("Capture differs from selection");
        ((ValuePattern)Child(dialog,"TitleBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue("List project files");
        var category=Child(dialog,"CategoryBox");category.SetFocus();Forms.SendKeys.SendWait("{HOME}{DOWN}{DOWN}{TAB}");
        var favourite=dialog.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.NameProperty,"Favorite"));
        ((TogglePattern)favourite.GetCurrentPattern(TogglePattern.Pattern)).Toggle();await Task.Delay(700);
        var save=dialog.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.NameProperty,"Save"));
        ((InvokePattern)save.GetCurrentPattern(InvokePattern.Pattern)).Invoke();await Task.Delay(1000);
        var saved=await repo.LoadAsync();
        var phrase=saved.Phrases.Single();if(phrase.Text!=Phrase || phrase.Title!="List project files" || phrase.CategoryId!=code.Id)throw new Exception("Saved library incorrect");
        Mark("batch snippet saved to Code and editor dismissed");
        source.Activate();editor.Focus();editor.Clear();await Task.Delay(600);
        OpenMenu();await Task.Delay(700);
        Forms.SendKeys.SendWait("{DOWN}{DOWN}{RIGHT}");await Task.Delay(1000);Mark("native Favourites submenu visible");
        Forms.SendKeys.SendWait("{ENTER}");await Task.Delay(1200);
        if(editor.Text!=Phrase)throw new Exception("Real paste failed: "+editor.Text);
        Mark("batch snippet pasted correctly");await Task.Delay(1200);
        // Start a separate real application session for the manager/context recording.
        commonCopy.Kill(true);commonCopy.WaitForExit();await Task.Delay(250);
        commonCopy=Process.Start(new ProcessStartInfo(Path.GetFullPath(exe)) { WorkingDirectory=Path.GetDirectoryName(Path.GetFullPath(exe))! })!;
        await WaitWindow("CommonCopy");await Task.Delay(900);
        Mark("manager shows saved phrase");await Task.Delay(1000);
        var libraryWindow=FindWindow(commonCopy.Id,"CommonCopy");
        ((ValuePattern)Child(libraryWindow,"SearchBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue("project");
        Mark("real manager search finds saved phrase");await Task.Delay(1400);
        ((ValuePattern)Child(libraryWindow,"SearchBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue("");await Task.Delay(1000);
        var add=libraryWindow.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.NameProperty,"Add phrase"));
        ((InvokePattern)add.GetCurrentPattern(InvokePattern.Pattern)).Invoke();
        var promptDialog=await WaitWindow("Phrase");
        const string promptText="Turn the notes below into a clear project brief. Include the goal, intended audience, deliverables, and three practical next steps.\r\n\r\nNotes: [paste your notes here]";
        ((ValuePattern)Child(promptDialog,"TitleBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue("Draft a project brief");
        ((ValuePattern)Child(promptDialog,"TextBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue(promptText);
        Child(promptDialog,"CategoryBox").SetFocus();Forms.SendKeys.SendWait("{HOME}{DOWN}{TAB}");
        Mark("different workflow: adding a GPT prompt");await Task.Delay(1300);
        var promptSave=promptDialog.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.NameProperty,"Save"));
        ((InvokePattern)promptSave.GetCurrentPattern(InvokePattern.Pattern)).Invoke();await Task.Delay(900);
        heading.Text="GPT prompt · ready to paste";editor.FontFamily=new FontFamily("Segoe UI");
        source.Activate();editor.Focus();editor.Clear();await Task.Delay(400);
        OpenMenu();await Task.Delay(700);Forms.SendKeys.SendWait("{DOWN}{DOWN}{DOWN}{DOWN}{RIGHT}");await Task.Delay(700);
        Forms.SendKeys.SendWait("{RIGHT}");await Task.Delay(1100);Mark("nested Prompts GPT submenu visible");
        Forms.SendKeys.SendWait("{DOWN}{ENTER}");await Task.Delay(1200);
        if(editor.Text!=promptText)throw new Exception("Nested prompt paste failed: "+editor.Text);
        Mark("different saved GPT prompt pasted correctly");await Task.Delay(1000);
        // A real local HTML page in an embedded browser, not a screenshot or text-box imitation.
        webpageMode=true;webpage=new WebBrowser();
        var webRoot=new DockPanel();
        var address=new TextBlock { Text="Webpage · local example article", FontSize=15,Padding=new Thickness(24,15,24,15),Background=new SolidColorBrush(Color.FromRgb(245,245,245)) };
        DockPanel.SetDock(address,Dock.Top);webRoot.Children.Add(address);webRoot.Children.Add(webpage);source.Content=webRoot;
        var pageLoaded=new TaskCompletionSource<bool>();webpage.LoadCompleted+=(_,_)=>pageLoaded.TrySetResult(true);
        webpage.NavigateToString("<!doctype html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'><style>body{font-family:Segoe UI,Arial,sans-serif;color:#111;background:white;margin:48px 64px;line-height:1.65}nav{font-size:14px;border-bottom:1px solid #bbb;padding-bottom:20px}h1{font-size:34px;font-weight:500}p{font-size:21px;max-width:800px}small{color:#555}</style></head><body><nav>WORK NOTES &nbsp; / &nbsp; Planning</nav><h1>Start with a clear brief.</h1><p>Good work starts with a shared understanding of what needs to happen.</p><p id='excerpt'>"+WebText+"</p><p>Keep the essentials somewhere easy to find, and return to them as the project develops.</p><small>Local example article for the CommonCopy demonstration.</small></body></html>");
        await pageLoaded.Task.WaitAsync(TimeSpan.FromSeconds(10));source.Activate();webpage.Focus();await Task.Delay(900);
        Mark("webpage article visible");
        dynamic html=webpage.Document;dynamic range=html.body.createTextRange();range.moveToElementText(html.getElementById("excerpt"));range.select();
        Mark("webpage paragraph highlighted");await Task.Delay(800);
        OpenMenu();await Task.Delay(900);Mark("webpage native capture menu visible");Forms.SendKeys.SendWait("{DOWN}{ENTER}");
        var webDialog=await WaitWindow("Save highlighted text");await Task.Delay(500);
        var captured=((ValuePattern)Child(webDialog,"TextBox").GetCurrentPattern(ValuePattern.Pattern)).Current.Value;
        if(captured.Trim()!=WebText)throw new Exception("Webpage capture mismatch");
        ((ValuePattern)Child(webDialog,"TitleBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue("Project brief checklist");
        Child(webDialog,"CategoryBox").SetFocus();Forms.SendKeys.SendWait("{END}{TAB}");
        Mark("webpage paragraph in real capture editor");await Task.Delay(1200);
        ((InvokePattern)webDialog.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.NameProperty,"Save")).GetCurrentPattern(InvokePattern.Pattern)).Invoke();await Task.Delay(1000);
        var finalDoc=await repo.LoadAsync();var webPhrase=finalDoc.Phrases.Single(p=>p.Title=="Project brief checklist");
        if(webPhrase.Text.Trim()!=WebText || webPhrase.CategoryId!=research.Id)throw new Exception("Webpage phrase not saved correctly");
        Mark("webpage paragraph saved to Research and editor dismissed");await Task.Delay(1000);
        capture=false;await recording;if(captureError is not null)throw captureError;
        File.WriteAllText(Path.Combine(output,"workflow.json"),JsonSerializer.Serialize(new { platform="Windows", source="Actual CommonCopy native application on disposable CI desktop; external editor and local HTML browser are recording fixtures", realCaptureVerified=true, realPersistedSaveVerified=true, realPasteVerified=true, realCodePasteVerified=true, realPromptPasteVerified=true, realWebCaptureVerified=true, events },new JsonSerializerOptions{WriteIndented=true}));
    }
    static void Mark(string name) {
        events.Add(new { seconds=clock.Elapsed.TotalSeconds, action=name });
        File.WriteAllText(Path.Combine(output,"events.json"),JsonSerializer.Serialize(events));
    }
    static AutomationElement Child(AutomationElement window,string id)=>window.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.AutomationIdProperty,id)) ?? throw new Exception("Missing control "+id);
    static AutomationElement FindWindow(int pid,string? name)
    {
        IntPtr found=IntPtr.Zero;
        EnumWindows((handle,_)=> {
            GetWindowThreadProcessId(handle,out var owner);
            if(owner!=(uint)pid || !IsWindowVisible(handle))return true;
            var title=new System.Text.StringBuilder(512);GetWindowText(handle,title,title.Capacity);
            if(name is null || title.ToString().Contains(name)){found=handle;return false;}
            return true;
        },IntPtr.Zero);
        return found!=IntPtr.Zero ? AutomationElement.FromHandle(found) : throw new Exception("No visible window: "+name);
    }
    static async Task<AutomationElement> WaitWindow(string name)
    {
        for(int n=0;n<100;n++){try{return FindWindow(commonCopy.Id,name);}catch{await Task.Delay(100);}}throw new Exception("Timed out waiting for "+name);
    }
    static void OpenMenu()
    {
        source.Activate();if(webpageMode)webpage!.Focus();else editor.Focus();SetCursorPos(430,260);
        keybd_event(0x11,0,0,UIntPtr.Zero);mouse_event(0x0008,0,0,0,UIntPtr.Zero);mouse_event(0x0010,0,0,0,UIntPtr.Zero);keybd_event(0x11,0,2,UIntPtr.Zero);
    }
    static void CaptureFrames()
    {
        try {
            var bounds=Forms.Screen.PrimaryScreen!.Bounds;
            using var bmp=new System.Drawing.Bitmap(bounds.Width,bounds.Height);
            using var g=System.Drawing.Graphics.FromImage(bmp);
            var start=Stopwatch.StartNew();int index=0;
            while(capture){
                g.CopyFromScreen(bounds.Left,bounds.Top,0,0,bmp.Size);
                var ci=new CURSORINFO { cbSize=Marshal.SizeOf<CURSORINFO>() };
                if(GetCursorInfo(ref ci)&&ci.flags==1) {
                    var dc=g.GetHdc();
                    try { DrawIconEx(dc,ci.ptScreenPos.X-bounds.Left,ci.ptScreenPos.Y-bounds.Top,ci.hCursor,0,0,0,IntPtr.Zero,3); }
                    finally { g.ReleaseHdc(dc); }
                }
                bmp.Save(Path.Combine(output,$"frame-{index:D5}.jpg"),System.Drawing.Imaging.ImageFormat.Jpeg);
                index++;var remaining=index*100-start.ElapsedMilliseconds;if(remaining>0)Thread.Sleep((int)remaining);
            }
            File.WriteAllText(Path.Combine(output,"capture.json"),JsonSerializer.Serialize(new{frames=index,elapsedSeconds=start.Elapsed.TotalSeconds,width=bounds.Width,height=bounds.Height}));
        }catch(Exception error){captureError=error;}
    }
    [StructLayout(LayoutKind.Sequential)] struct POINT{public int X,Y;}
    [StructLayout(LayoutKind.Sequential)] struct CURSORINFO{public int cbSize;public int flags;public IntPtr hCursor;public POINT ptScreenPos;}
    delegate bool EnumCallback(IntPtr window,IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumCallback callback,IntPtr parameter);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr window,System.Text.StringBuilder text,int count);
    [DllImport("user32.dll")] static extern bool GetCursorInfo(ref CURSORINFO ci);
    [DllImport("user32.dll")] static extern bool DrawIconEx(IntPtr dc,int x,int y,IntPtr icon,int cx,int cy,int step,IntPtr brush,int flags);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr window,int state);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
    [DllImport("user32.dll")] static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd,uint message,IntPtr w,IntPtr l);
}
