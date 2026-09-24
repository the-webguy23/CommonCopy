using Drawing = System.Drawing;
using Forms = System.Windows.Forms;

namespace CommonCopy.Windows.Services;

public sealed class TrayIconService : IDisposable
{
    private readonly Forms.NotifyIcon notifyIcon;
    private bool disposed;

    public TrayIconService(Action showManager, Action showPopup, Action exit)
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add("Open Phrase Manager", null, (_, _) => showManager());
        menu.Items.Add("Show CommonCopy", null, (_, _) => showPopup());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Exit", null, (_, _) => exit());

        notifyIcon = new Forms.NotifyIcon
        {
            ContextMenuStrip = menu,
            Icon = Drawing.SystemIcons.Application,
            Text = "CommonCopy",
            Visible = true,
        };
        notifyIcon.DoubleClick += (_, _) => showManager();
    }

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
        GC.SuppressFinalize(this);
    }
}
