package app.commoncopy.mobile;

import android.inputmethodservice.InputMethodService;
import android.view.*;
import android.view.inputmethod.*;
import android.widget.*;
import org.json.*;
import java.util.*;

/** Phrase-only input method. Does not observe keys or inspect surrounding text. */
public final class PhraseKeyboard extends InputMethodService {
    private String filter="favourites";
    private LinearLayout root;
    private LibraryStore store;
    @Override public View onCreateInputView(){store=new LibraryStore(this);root=UI.column(this);render();return root;}
    @Override public void onStartInputView(EditorInfo info,boolean restarting){super.onStartInputView(info,restarting);if(root!=null)render();}
    @Override public boolean onEvaluateFullscreenMode(){return false;}
    private void render(){
        root.removeAllViews();root.addView(UI.text(this,"CommonCopy",18));
        LinearLayout controls=new LinearLayout(this);controls.addView(UI.button(this,"Categories",this::categories));controls.addView(UI.button(this,"Next keyboard",()->((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).showInputMethodPicker()));controls.addView(UI.button(this,"⌫",()->{InputConnection input=getCurrentInputConnection();if(input!=null)input.deleteSurroundingTextInCodePoints(1,0);}));root.addView(controls);
        ScrollView scroll=new ScrollView(this);LinearLayout phrases=UI.column(this);scroll.addView(phrases);root.addView(scroll,new LinearLayout.LayoutParams(-1,UI.dp(this,200)));
        try{
            Library lib=store.load();List<JSONObject> entries=lib.visible(filter,"");if(entries.isEmpty())phrases.addView(UI.text(this,"No phrases in this category. Try All phrases, or add some in the CommonCopy app.",14));
            for(JSONObject phrase:entries){String id=phrase.getString("Id");phrases.addView(UI.button(this,phrase.getString("Title"),()->{
                try{
                    // Reload on tap so edits/deletions in the app take effect immediately.
                    Library current=store.load();JSONObject fresh=current.find(id);
                    if(!fresh.optBoolean("IsEnabled",true)||!current.categoryEnabled(fresh.getString("CategoryId"))){render();return;}
                    InputConnection input=getCurrentInputConnection();
                    if(input!=null && input.commitText(fresh.getString("Text"),1))store.change(l->l.used(id));
                }catch(Exception e){Toast.makeText(this,"Couldn't insert this phrase. Reopen CommonCopy to check your library.",Toast.LENGTH_LONG).show();}
            }));}
        }catch(Exception e){phrases.addView(UI.text(this,"Couldn't read your library. Open CommonCopy to check it.",14));}
    }
    private void categories(){
        try{Library lib=store.load();List<String> labels=new ArrayList<>(List.of("All phrases","Favourites","Commonly Used"));List<String> values=new ArrayList<>(List.of("all","favourites","common"));for(JSONObject c:lib.categories())if(lib.categoryEnabled(c.getString("Id"))){labels.add(lib.categoryPath(c.getString("Id")));values.add(c.getString("Id"));}
            PopupMenu menu=new PopupMenu(this,root.getChildAt(0));for(int i=0;i<labels.size();i++){final String value=values.get(i);menu.getMenu().add(labels.get(i)).setOnMenuItemClickListener(item->{filter=value;render();return true;});}menu.show();
        }catch(Exception e){Toast.makeText(this,"Couldn't open categories.",Toast.LENGTH_SHORT).show();}
    }
}
