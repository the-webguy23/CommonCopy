package app.commoncopy.mobile;

import android.content.Context;
import android.util.AtomicFile;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;

/** App, share receiver and IME run in one process. Each change reloads under one lock. */
public final class LibraryStore {
    private static final Object LOCK=new Object();
    private final AtomicFile file;
    private final AtomicFile backup;
    public interface Change { void apply(Library library) throws Exception; }
    public LibraryStore(Context context) {
        file=new AtomicFile(new File(context.getFilesDir(),"phrases.json"));
        backup=new AtomicFile(new File(context.getFilesDir(),"phrases.previous.json"));
    }
    public Library load() throws Exception { synchronized(LOCK) { return loadLocked(); } }
    private Library loadLocked() throws Exception {
        if(!file.getBaseFile().exists() && !new File(file.getBaseFile()+".bak").exists()) { Library lib=Library.empty();write(file,lib.json.toString(2));return lib; }
        // Invalid data is surfaced rather than overwritten with empty defaults.
        return new Library(new JSONObject(new String(file.readFully(),StandardCharsets.UTF_8)));
    }
    public void change(Change action) throws Exception {
        synchronized(LOCK) { Library lib=loadLocked();String previous=lib.json.toString(2);action.apply(lib);lib.validate();write(backup,previous);write(file,lib.json.toString(2)); }
    }
    public void importJSON(String data) throws Exception {
        Library imported=new Library(new JSONObject(data));
        synchronized(LOCK) { Library old=loadLocked();write(backup,old.json.toString(2));write(file,imported.json.toString(2)); }
    }
    static void write(AtomicFile file,String value) throws IOException {
        FileOutputStream out=null;
        try { out=file.startWrite();out.write(value.getBytes(StandardCharsets.UTF_8));file.finishWrite(out); }
        catch(IOException e){if(out!=null)file.failWrite(out);throw e;}
    }
}
