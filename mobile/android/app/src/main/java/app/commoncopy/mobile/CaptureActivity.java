package app.commoncopy.mobile;

import android.app.*;
import android.os.Bundle;
import android.content.*;
import android.widget.*;
import org.json.*;
import java.util.*;

/** Receives only text explicitly shared or selected by the user. */
public final class CaptureActivity extends Activity {
    private LibraryStore store;
    @Override public void onCreate(Bundle b){super.onCreate(b);store=new LibraryStore(this);
        Intent input=getIntent();boolean process=Intent.ACTION_PROCESS_TEXT.equals(input.getAction());
        if(!process&&!Intent.ACTION_SEND.equals(input.getAction())){finish();return;}
        CharSequence value=input.getCharSequenceExtra(process?Intent.EXTRA_PROCESS_TEXT:Intent.EXTRA_TEXT);
        if(value==null||value.length()>1_000_000){Toast.makeText(this,"Share a smaller text selection.",Toast.LENGTH_LONG).show();finish();return;}
        LinearLayout root=UI.column(this);root.addView(UI.text(this,"CommonCopy",26));root.addView(UI.button(this,"Save selected text…",()->UI.editor(this,store,null,value.toString(),()->{setResult(RESULT_CANCELED);finish();})));
        boolean readonly=input.getBooleanExtra(Intent.EXTRA_PROCESS_TEXT_READONLY,true);
        root.addView(UI.text(this,process&&!readonly?"Choose a phrase to replace the selection.":"Choose a phrase to copy, then paste it where you need it.",14));
        ScrollView scroll=new ScrollView(this);LinearLayout list=UI.column(this);scroll.addView(list);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));setContentView(root);
        try{for(JSONObject phrase:store.load().visible("all","")){String id=phrase.getString("Id");list.addView(UI.button(this,phrase.getString("Title"),()->{
            try{String text=store.load().find(id).getString("Text");if(process&&!readonly){setResult(RESULT_OK,new Intent().putExtra(Intent.EXTRA_PROCESS_TEXT,text));}
            else{((ClipboardManager)getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("CommonCopy",text));Toast.makeText(this,"Copied",Toast.LENGTH_SHORT).show();}
            store.change(lib->lib.used(id));finish();}catch(Exception e){UI.error(this);}
        }));}}catch(Exception e){UI.error(this);}
        root.setOnApplyWindowInsetsListener((v,insets)->{android.graphics.Insets i=insets.getInsets(android.view.WindowInsets.Type.systemBars()|android.view.WindowInsets.Type.ime());v.setPadding(UI.dp(this,20)+i.left,UI.dp(this,16)+i.top,UI.dp(this,20)+i.right,UI.dp(this,16)+i.bottom);return insets;});
    }
}
