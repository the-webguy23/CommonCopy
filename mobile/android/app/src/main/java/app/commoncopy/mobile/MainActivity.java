package app.commoncopy.mobile;

import android.app.*;
import android.os.Bundle;
import android.content.*;
import android.provider.Settings;
import android.text.Editable;
import android.text.TextWatcher;
import android.widget.*;
import org.json.*;
import java.util.*;
import java.io.*;
import java.nio.charset.StandardCharsets;

public final class MainActivity extends Activity {
    private LibraryStore store;
    private LinearLayout list;
    private String filter="all",query="";
    private static final int IMPORT=10,EXPORT=11;
    @Override public void onCreate(Bundle b){super.onCreate(b);store=new LibraryStore(this);screen();}
    @Override public void onResume(){super.onResume();if(list!=null)render();}
    private void screen(){
        LinearLayout root=UI.column(this);setContentView(root);
        root.addView(UI.text(this,"CommonCopy",28));root.addView(UI.text(this,"Save it once. Paste it forever.",14));
        root.addView(UI.button(this,"Add phrase",()->UI.editor(this,store,null,"",this::render)));
        root.addView(UI.button(this,"Library & keyboard setup",this::settings));
        EditText search=new EditText(this);search.setHint("Search phrases");search.setSingleLine(true);search.setText(query);root.addView(search);
        search.addTextChangedListener(new TextWatcher(){public void beforeTextChanged(CharSequence s,int a,int c,int f){}public void onTextChanged(CharSequence s,int st,int b,int c){query=s.toString();render();}public void afterTextChanged(Editable e){}});
        Spinner filters=new Spinner(this);
        try {
            Library lib=store.load();List<String> labels=new ArrayList<>(List.of("All phrases","Favourites","Commonly Used"));List<String> values=new ArrayList<>(List.of("all","favourites","common"));
            for(JSONObject c:lib.categories()){labels.add(lib.categoryPath(c.getString("Id")));values.add(c.getString("Id"));}
            filters.setAdapter(new ArrayAdapter<>(this,android.R.layout.simple_spinner_dropdown_item,labels));filters.setSelection(Math.max(0,values.indexOf(filter)));
            filters.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener(){public void onItemSelected(android.widget.AdapterView<?> a,android.view.View v,int p,long id){filter=values.get(p);render();}public void onNothingSelected(android.widget.AdapterView<?> a){}});
        }catch(Exception e){UI.error(this);}root.addView(filters);
        ScrollView scroll=new ScrollView(this);list=UI.column(this);list.setPadding(0,0,0,0);scroll.addView(list);root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));render();
        // Insets keep controls above gesture navigation and display cutouts on Android 15+.
        root.setOnApplyWindowInsetsListener((v,insets)->{android.graphics.Insets i=insets.getInsets(android.view.WindowInsets.Type.systemBars()|android.view.WindowInsets.Type.ime());v.setPadding(UI.dp(this,20)+i.left,UI.dp(this,16)+i.top,UI.dp(this,20)+i.right,UI.dp(this,16)+i.bottom);return insets;});
    }
    private void render(){
        if(list==null)return;list.removeAllViews();
        try {Library lib=store.load();List<JSONObject> phrases=lib.visible(filter,query);if(phrases.isEmpty())list.addView(UI.text(this,"No phrases here yet. Add one or import your library.",15));
            for(JSONObject phrase:phrases){String id=phrase.getString("Id");list.addView(UI.text(this,(phrase.optBoolean("IsFavorite")?"★ ":"")+phrase.getString("Title"),18));TextView preview=UI.text(this,phrase.getString("Text"),14);preview.setMaxLines(3);list.addView(preview);
                LinearLayout actions=new LinearLayout(this);actions.addView(UI.button(this,"Copy",()->copy(id)));actions.addView(UI.button(this,"Edit",()->UI.editor(this,store,id,"",this::render)));actions.addView(UI.button(this,"Delete",()->new AlertDialog.Builder(this).setTitle("Delete this phrase?").setNegativeButton("Cancel",null).setPositiveButton("Delete",(d,w)->{try{store.change(l->l.remove(id));render();}catch(Exception e){UI.error(this);}}).show()));list.addView(actions);UI.line(this,list);
            }
        }catch(Exception e){list.addView(UI.text(this,"Couldn't open your library. The stored file has been kept.",15));}
    }
    private void copy(String id){try{JSONObject p=store.load().find(id);((ClipboardManager)getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("CommonCopy",p.getString("Text")));store.change(l->l.used(id));Toast.makeText(this,"Copied",Toast.LENGTH_SHORT).show();}catch(Exception e){UI.error(this);}}
    private void settings(){new AlertDialog.Builder(this).setTitle("Library & keyboard").setItems(new String[]{"Add category","Import library…","Export library…","Enable CommonCopy keyboard","Choose keyboard","How to use"},(d,which)->{
        switch(which){case 0:UI.newCategory(this,store,this::screen);break;
        case 1:new AlertDialog.Builder(this).setTitle("Replace library from a file?").setMessage("Export a backup first. Import replaces this device's library and keeps the previous file locally.").setNegativeButton("Cancel",null).setPositiveButton("Choose file",(a,b)->startActivityForResult(new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("*/*").addCategory(Intent.CATEGORY_OPENABLE),IMPORT)).show();break;
        case 2:startActivityForResult(new Intent(Intent.ACTION_CREATE_DOCUMENT).setType("application/json").putExtra(Intent.EXTRA_TITLE,"CommonCopy-library.json").addCategory(Intent.CATEGORY_OPENABLE),EXPORT);break;
        case 3:startActivity(new Intent(Settings.ACTION_INPUT_METHOD_SETTINGS));break;
        case 4:((android.view.inputmethod.InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).showInputMethodPicker();break;
        default:new AlertDialog.Builder(this).setTitle("Your phrases, wherever you type").setMessage("Save selected text using Share → CommonCopy, or the CommonCopy text-selection action in supported apps.\n\nEnable the CommonCopy keyboard, then switch to it to insert a phrase. Use Next keyboard to return to your regular keyboard.\n\nEverything stays on this device. No accounts or network access. Your library is readable text, so keep secrets in a password manager.").setPositiveButton("Got it",null).show();}
    }).show();}
    @Override protected void onActivityResult(int req,int result,Intent data){super.onActivityResult(req,result,data);if(result!=RESULT_OK||data==null||data.getData()==null)return;
        try{if(req==EXPORT){try(OutputStream out=getContentResolver().openOutputStream(data.getData(),"wt")){if(out==null)throw new IOException();out.write(store.load().json.toString(2).getBytes(StandardCharsets.UTF_8));}Toast.makeText(this,"Library exported",Toast.LENGTH_SHORT).show();}
        else if(req==IMPORT){try(InputStream in=getContentResolver().openInputStream(data.getData())){if(in==null)throw new IOException();ByteArrayOutputStream buffer=new ByteArrayOutputStream();byte[] block=new byte[8192];int n;while((n=in.read(block))!=-1){buffer.write(block,0,n);if(buffer.size()>5*1024*1024)throw new IOException();}byte[] bytes=buffer.toByteArray();if(bytes.length>5*1024*1024)throw new IOException();store.importJSON(new String(bytes,StandardCharsets.UTF_8));}filter="all";screen();}}
        catch(Exception e){UI.error(this);}}
}
