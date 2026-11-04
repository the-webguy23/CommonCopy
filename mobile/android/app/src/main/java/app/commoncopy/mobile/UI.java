package app.commoncopy.mobile;

import android.app.*;
import android.content.*;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.util.*;

final class UI {
    static int dp(Context c,int value){return Math.round(value*c.getResources().getDisplayMetrics().density);}
    static LinearLayout column(Context c){LinearLayout v=new LinearLayout(c);v.setOrientation(LinearLayout.VERTICAL);v.setPadding(dp(c,20),dp(c,16),dp(c,20),dp(c,16));v.setBackgroundColor(Color.WHITE);return v;}
    static TextView text(Context c,String text,int size){TextView v=new TextView(c);v.setText(text);v.setTextSize(size);v.setTextColor(Color.rgb(17,17,17));v.setPadding(0,dp(c,8),0,dp(c,8));return v;}
    static Button button(Context c,String label,Runnable action){Button b=new Button(c);b.setText(label);b.setAllCaps(false);b.setTextColor(Color.BLACK);GradientDrawable bg=new GradientDrawable();bg.setColor(Color.WHITE);bg.setCornerRadius(dp(c,20));bg.setStroke(dp(c,1),Color.LTGRAY);b.setBackground(bg);b.setMinHeight(dp(c,48));b.setPadding(dp(c,14),dp(c,8),dp(c,14),dp(c,8));b.setOnClickListener(v->action.run());return b;}
    static void error(Context c){new AlertDialog.Builder(c).setTitle("Couldn't complete that").setMessage("Your library has been kept. Check the file or try again. If the problem continues, export a backup before making changes.").setPositiveButton("OK",null).show();}
    static void line(Context c,LinearLayout parent){View v=new View(c);v.setBackgroundColor(Color.LTGRAY);parent.addView(v,new LinearLayout.LayoutParams(-1,dp(c,1)));}
    interface Saved{void done();}
    static void editor(Activity activity,LibraryStore store,String id,String captured,Saved saved){
        try {
            Library library=store.load();JSONObject phrase=id==null?null:library.find(id);
            LinearLayout body=column(activity);
            EditText title=new EditText(activity);title.setHint("Title");title.setSingleLine(true);title.setText(phrase==null?"":phrase.getString("Title"));body.addView(title);
            EditText text=new EditText(activity);text.setHint("Your words");text.setMinLines(4);text.setMaxLines(7);text.setGravity(Gravity.TOP);text.setInputType(android.text.InputType.TYPE_CLASS_TEXT|android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE);text.setText(phrase==null?captured:phrase.getString("Text"));body.addView(text);
            List<JSONObject> cats=library.categories();List<String> names=new ArrayList<>();for(JSONObject cat:cats)names.add(library.categoryPath(cat.getString("Id")));
            Spinner categories=new Spinner(activity);categories.setAdapter(new ArrayAdapter<>(activity,android.R.layout.simple_spinner_dropdown_item,names));body.addView(categories);
            if(phrase!=null)for(int i=0;i<cats.size();i++)if(cats.get(i).getString("Id").equalsIgnoreCase(phrase.getString("CategoryId")))categories.setSelection(i);
            CheckBox fav=new CheckBox(activity);fav.setText("Favourite");fav.setChecked(phrase!=null&&phrase.optBoolean("IsFavorite"));body.addView(fav);
            TextView validation=text(activity,"",12);body.addView(validation);
            AlertDialog dialog=new AlertDialog.Builder(activity).setTitle(id==null?"Save a phrase":"Edit phrase").setView(body).setNegativeButton("Cancel",(d,w)->{if(activity instanceof CaptureActivity)activity.finish();}).setPositiveButton("Save",null).create();
            dialog.setOnCancelListener(d->{if(activity instanceof CaptureActivity)activity.finish();});
            dialog.setOnShowListener(d->dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v->{
                if(title.getText().toString().trim().isEmpty()||text.getText().length()==0||cats.isEmpty()){validation.setText("Add a title, text, and category.");return;}
                try {String cat=cats.get(categories.getSelectedItemPosition()).getString("Id");store.change(lib->lib.savePhrase(id,title.getText().toString(),text.getText().toString(),cat,fav.isChecked()));dialog.dismiss();saved.done();}
                catch(Exception e){validation.setText("Couldn't save. Your existing library has been kept.");}
            }));dialog.show();
        }catch(Exception e){error(activity);}
    }
    static void newCategory(Activity activity,LibraryStore store,Runnable refresh){
        try {
            Library library=store.load();List<JSONObject> cats=library.categories();LinearLayout view=column(activity);EditText name=new EditText(activity);name.setHint("Category name");view.addView(name);
            Spinner parent=new Spinner(activity);List<String> choices=new ArrayList<>(List.of("No parent"));for(JSONObject c:cats)choices.add(library.categoryPath(c.getString("Id")));parent.setAdapter(new ArrayAdapter<>(activity,android.R.layout.simple_spinner_dropdown_item,choices));view.addView(parent);
            AlertDialog dialog=new AlertDialog.Builder(activity).setTitle("Add category").setView(view).setNegativeButton("Cancel",null).setPositiveButton("Save",null).create();
            dialog.setOnShowListener(d->dialog.getButton(-1).setOnClickListener(v->{if(name.getText().toString().trim().isEmpty()){name.setError("Enter a name");return;}try{String pid=parent.getSelectedItemPosition()==0?null:cats.get(parent.getSelectedItemPosition()-1).getString("Id");store.change(lib->lib.addCategory(name.getText().toString(),pid));dialog.dismiss();refresh.run();}catch(Exception e){error(activity);}}));dialog.show();
        }catch(Exception e){error(activity);}
    }
}
