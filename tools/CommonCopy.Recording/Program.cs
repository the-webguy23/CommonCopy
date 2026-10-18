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
    const string Phrase = "Thanks for the update. I’ll review this and get back to you tomorrow.";
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
            FontFamily = new FontFamily("Segoe UI"), FontSize = 22, Padding = new Thickness(36), BorderThickness = new Thickness(0), Background = Brushes.White };
        var root = new DockPanel();
        var heading = new TextBlock { Text = "Project notes", FontSize = 16, Padding = new Thickness(24,16,24,16), Background = new SolidColorBrush(Color.FromRgb(245,245,245)) };
        DockPanel.SetDock(heading,Dock.Top);root.Children.Add(heading);root.Children.Add(editor);
        source = new Window { Title="Project notes — recording fixture", Width=980, Height=620, Left=20, Top=20, Content=root, WindowState=WindowState.Maximized, Background=Brushes.White };
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
        var doc=new PhraseLibraryDocument();doc.Categories.AddRange(new[]{prompts,gpt});
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
        ((ValuePattern)Child(dialog,"TitleBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue("Quick follow-up");
        var category=Child(dialog,"CategoryBox");category.SetFocus();Forms.SendKeys.SendWait("{END}{TAB}");
        var favourite=dialog.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.NameProperty,"Favorite"));
        ((TogglePattern)favourite.GetCurrentPattern(TogglePattern.Pattern)).Toggle();await Task.Delay(700);
        var save=dialog.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.NameProperty,"Save"));
        ((InvokePattern)save.GetCurrentPattern(InvokePattern.Pattern)).Invoke();await Task.Delay(1000);
        var saved=await repo.LoadAsync();
        var phrase=saved.Phrases.Single();if(phrase.Text!=Phrase || phrase.Title!="Quick follow-up" || phrase.CategoryId!=gpt.Id)throw new Exception("Saved library incorrect");
        Mark("capture saved to Prompts/GPT and editor dismissed");
        source.Activate();editor.Focus();editor.Clear();await Task.Delay(600);
        OpenMenu();await Task.Delay(700);
        Forms.SendKeys.SendWait("{DOWN}{DOWN}{RIGHT}");await Task.Delay(1000);Mark("native Favourites submenu visible");
        Forms.SendKeys.SendWait("{ENTER}");await Task.Delay(1200);
        if(editor.Text!=Phrase)throw new Exception("Real paste failed: "+editor.Text);
        Mark("real saved phrase pasted into editor");await Task.Delay(1200);
        OpenMenu();await Task.Delay(600);Forms.SendKeys.SendWait("{DOWN}{DOWN}{DOWN}{DOWN}{DOWN}{ENTER}");await Task.Delay(1400);
        Mark("manager shows saved phrase");await Task.Delay(1000);
        var libraryWindow=FindWindow(commonCopy.Id,"CommonCopy");
        ((ValuePattern)Child(libraryWindow,"SearchBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue("Quick");
        Mark("real manager search finds saved phrase");await Task.Delay(1400);
        ((ValuePattern)Child(libraryWindow,"SearchBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue("");await Task.Delay(1000);
        var add=libraryWindow.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.NameProperty,"Add phrase"));
        ((InvokePattern)add.GetCurrentPattern(InvokePattern.Pattern)).Invoke();
        var promptDialog=await WaitWindow("Phrase");
        const string promptText="Summarize the text below in three clear bullet points. Finish with one practical next step.";
        ((ValuePattern)Child(promptDialog,"TitleBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue("Summarize a document");
        ((ValuePattern)Child(promptDialog,"TextBox").GetCurrentPattern(ValuePattern.Pattern)).SetValue(promptText);
        Child(promptDialog,"CategoryBox").SetFocus();Forms.SendKeys.SendWait("{END}{TAB}");
        Mark("different workflow: adding a GPT prompt");await Task.Delay(1300);
        var promptSave=promptDialog.FindFirst(TreeScope.Descendants,new PropertyCondition(AutomationElement.NameProperty,"Save"));
        ((InvokePattern)promptSave.GetCurrentPattern(InvokePattern.Pattern)).Invoke();await Task.Delay(900);
        source.Activate();editor.Focus();editor.Clear();await Task.Delay(400);
        OpenMenu();await Task.Delay(700);Forms.SendKeys.SendWait("{DOWN}{DOWN}{DOWN}{DOWN}{RIGHT}");await Task.Delay(700);
        Forms.SendKeys.SendWait("{RIGHT}");await Task.Delay(1100);Mark("nested Prompts GPT submenu visible");
        Forms.SendKeys.SendWait("{DOWN}{ENTER}");await Task.Delay(1200);
        if(editor.Text!=promptText)throw new Exception("Nested prompt paste failed: "+editor.Text);
        Mark("different saved GPT prompt pasted correctly");await Task.Delay(1000);
        capture=false;await recording;if(captureError is not null)throw captureError;
        File.WriteAllText(Path.Combine(output,"workflow.json"),JsonSerializer.Serialize(new { platform="Windows", source="Actual CommonCopy native application on disposable CI desktop; external editor is a plain WPF recording fixture", realCaptureVerified=true, realPersistedSaveVerified=true, realPasteVerified=true, events },new JsonSerializerOptions{WriteIndented=true}));
    }
    static void Mark(string name)=>events.Add(new { seconds=clock.Elapsed.TotalSeconds, action=name });
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
        source.Activate();editor.Focus();SetCursorPos(430,260);
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
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
    [DllImport("user32.dll")] static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd,uint message,IntPtr w,IntPtr l);
}
