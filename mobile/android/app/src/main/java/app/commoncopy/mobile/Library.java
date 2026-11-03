package app.commoncopy.mobile;

import org.json.*;
import java.time.Instant;
import java.util.*;

/** Desktop schema 1. Preserve settings and unknown fields when round-tripping. */
public final class Library {
    public final JSONObject json;
    public Library(JSONObject json) throws JSONException { this.json = json; validate(); }
    public static String now() { return Instant.now().toString(); }
    public static Library empty() throws JSONException {
        JSONObject root = new JSONObject().put("SchemaVersion", 1).put("Categories", new JSONArray()).put("Phrases", new JSONArray()).put("Settings", new JSONObject());
        Library library = new Library(root);
        for (String name : List.of("Prompts", "Code", "Day-to-Day")) library.addCategory(name, null);
        return library;
    }
    public List<JSONObject> categories() throws JSONException { return objects(json.getJSONArray("Categories")); }
    public List<JSONObject> phrases() throws JSONException { return objects(json.getJSONArray("Phrases")); }
    static List<JSONObject> objects(JSONArray array) throws JSONException {
        List<JSONObject> list = new ArrayList<>();
        for (int i=0;i<array.length();i++) list.add(array.getJSONObject(i));
        return list;
    }
    static String key(JSONObject object, String key) throws JSONException { return object.getString(key).toLowerCase(Locale.ROOT); }
    public void validate() throws JSONException {
        if (json.getInt("SchemaVersion") != 1) throw new JSONException("Unsupported library version.");
        Map<String, JSONObject> cats = new HashMap<>();
        for (JSONObject c : categories()) {
            String id = key(c,"Id"); validUUID(id);
            if (c.getString("Name").trim().isEmpty() || cats.put(id,c)!=null) throw new JSONException("Invalid or duplicate category.");
        }
        for (JSONObject c : cats.values()) {
            Set<String> seen = new HashSet<>();
            JSONObject current=c;
            while (current != null) {
                if (!seen.add(key(current,"Id"))) throw new JSONException("Category cycle.");
                if (current.isNull("ParentId") || !current.has("ParentId")) break;
                current=cats.get(key(current,"ParentId"));
                if (current==null) throw new JSONException("Missing parent category.");
            }
        }
        Set<String> ids=new HashSet<>();
        for (JSONObject p : phrases()) {
            String id=key(p,"Id"); validUUID(id);
            if (!ids.add(id) || !cats.containsKey(key(p,"CategoryId")) || p.getString("Title").trim().isEmpty() || p.getString("Text").isEmpty()) throw new JSONException("Invalid phrase.");
        }
        if (!json.has("Settings")) json.put("Settings",new JSONObject());
    }
    static void validUUID(String value) throws JSONException {
        try { if (!UUID.fromString(value).toString().equals(value) || value.equals("00000000-0000-0000-0000-000000000000")) throw new IllegalArgumentException(); }
        catch (IllegalArgumentException e) { throw new JSONException("Invalid identifier."); }
    }
    public JSONObject find(String id) throws JSONException {
        for (JSONObject p:phrases()) if (key(p,"Id").equals(id.toLowerCase(Locale.ROOT))) return p;
        throw new JSONException("Phrase no longer exists.");
    }
    public String addCategory(String name, String parent) throws JSONException {
        if (name.trim().isEmpty()) throw new JSONException("Enter a category name.");
        String id=UUID.randomUUID().toString();
        json.getJSONArray("Categories").put(new JSONObject().put("Id",id).put("Name",name.trim()).put("ParentId",parent==null?JSONObject.NULL:parent).put("IsEnabled",true).put("SortOrder",categories().size()).put("CreatedAt",now()).put("UpdatedAt",now()));
        validate(); return id;
    }
    public String savePhrase(String id, String title, String text, String category, boolean favorite) throws JSONException {
        if (title.trim().isEmpty() || text.isEmpty()) throw new JSONException("Enter a title and some text.");
        JSONObject p;
        if (id==null) {
            p=new JSONObject().put("Id",UUID.randomUUID().toString()).put("CreatedAt",now()).put("IsEnabled",true).put("UseCount",0).put("SortOrder",phrases().size());
            json.getJSONArray("Phrases").put(p);
        } else p=find(id);
        p.put("Title",title.trim()).put("Text",text).put("CategoryId",category).put("IsFavorite",favorite).put("UpdatedAt",now());
        validate(); return p.getString("Id");
    }
    public void remove(String id) throws JSONException {
        JSONArray array=json.getJSONArray("Phrases");
        for(int i=0;i<array.length();i++) if(key(array.getJSONObject(i),"Id").equals(id.toLowerCase(Locale.ROOT))) { array.remove(i);return; }
    }
    public void used(String id) throws JSONException {
        JSONObject p=find(id);p.put("UseCount",Math.max(0,p.optInt("UseCount"))+1).put("LastUsedAt",now());
    }
    public boolean categoryEnabled(String id) throws JSONException {
        Map<String,JSONObject> map=new HashMap<>(); for(JSONObject c:categories()) map.put(key(c,"Id"),c);
        JSONObject c=map.get(id.toLowerCase(Locale.ROOT));
        while(c!=null) { if(!c.optBoolean("IsEnabled",true)) return false; c=c.isNull("ParentId")?null:map.get(c.optString("ParentId").toLowerCase(Locale.ROOT)); }
        return true;
    }
    public String categoryPath(String id) throws JSONException {
        for(JSONObject c:categories()) if(key(c,"Id").equals(id.toLowerCase(Locale.ROOT))) return (c.isNull("ParentId")?"":categoryPath(c.getString("ParentId"))+" / ")+c.getString("Name");
        return "";
    }
    public List<JSONObject> visible(String filter,String query) throws JSONException {
        List<JSONObject> result=new ArrayList<>(); String needle=query.toLowerCase(Locale.ROOT);
        for(JSONObject p:phrases()) {
            if(!p.optBoolean("IsEnabled",true)||!categoryEnabled(p.getString("CategoryId"))) continue;
            if(filter.equals("favourites")&&!p.optBoolean("IsFavorite"))continue;
            if(!List.of("all","favourites","common").contains(filter)&&!key(p,"CategoryId").equals(filter.toLowerCase(Locale.ROOT)))continue;
            if(!(p.getString("Title")+"\n"+p.getString("Text")).toLowerCase(Locale.ROOT).contains(needle))continue;
            result.add(p);
        }
        result.sort(filter.equals("common")?Comparator.<JSONObject>comparingInt(p->p.optInt("UseCount")).reversed().thenComparing(p->p.optString("LastUsedAt"),Comparator.reverseOrder()):Comparator.comparingInt(p->p.optInt("SortOrder")));
        return result;
    }
}
