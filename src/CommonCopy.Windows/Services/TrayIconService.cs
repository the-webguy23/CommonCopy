using System.Runtime.InteropServices;
using Drawing = System.Drawing;
using Forms = System.Windows.Forms;

namespace CommonCopy.Windows.Services;

public sealed class TrayIconService : IDisposable
{
    private readonly Forms.NotifyIcon notifyIcon;
    private bool disposed;
    private readonly Drawing.Icon appIcon;

    public TrayIconService(Action showManager, Action showPopup, Action exit)
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Open Phrase Manager", null, (_, _) => showManager());
        menu.Items.Add("Show CommonCopy", null, (_, _) => showPopup());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Exit", null, (_, _) => exit());

        // Use the approved original artwork; create only the standard small
        // notification-area representation and release the native bitmap handle.
        var resource = System.Windows.Application.GetResourceStream(
            new Uri("pack://application:,,,/CommonCopy;component/Assets/CommonCopyLogo.png"))
            ?? throw new InvalidOperationException("The CommonCopy logo resource is missing.");
        using (resource.Stream)
        using (var original = new Drawing.Bitmap(resource.Stream))
        using (var small = new Drawing.Bitmap(original, new Drawing.Size(32, 32)))
        {
            var handle = small.GetHicon();
            try
            {
                using var borrowed = Drawing.Icon.FromHandle(handle);
                appIcon = (Drawing.Icon)borrowed.Clone();
            }
            finally { DestroyIcon(handle); }
        }
        notifyIcon = new Forms.NotifyIcon
        {
            ContextMenuStrip = menu,
            Icon = appIcon,
            Text = "CommonCopy",
            Visible = true,
        };
        notifyIcon.DoubleClick += (_, _) => showManager();
    }

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(nint icon);

    public void Dispose()
    {
        if (disposed)
        {
            return;
        }

        disposed = true;
        notifyIcon.Visible = false;
        notifyIcon.ContextMenuStrip?.Dispose();
        notifyIcon.Dispose();
        appIcon.Dispose();
        GC.SuppressFinalize(this);
    }
}
