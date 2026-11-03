package app.commoncopy.mobile;
import org.junit.Test;
import org.json.*;
import java.nio.charset.StandardCharsets;
import static org.junit.Assert.*;

public class LibraryTest {
    private Library fixture() throws Exception {
        try(var in=getClass().getResourceAsStream("/desktop-library.json")) { return new Library(new JSONObject(new String(in.readAllBytes(),StandardCharsets.UTF_8))); }
    }
    @Test public void desktopRoundTripPreservesUnicodeAndSettings() throws Exception {
        Library lib=fixture();Library copy=new Library(new JSONObject(lib.json.toString()));
        assertEquals("Hello,\n世界 👋",copy.phrases().get(0).getString("Text"));
        assertEquals("preserve-me",copy.json.getJSONObject("Settings").getString("FutureSetting"));
        assertEquals("2026-10-01T12:00:00+00:00",copy.phrases().get(0).getString("CreatedAt"));
    }
    @Test public void disabledItemsNeverReachKeyboard() throws Exception { assertEquals(1,fixture().visible("all","").size()); }
    @Test public void categoryPathsAndFavorites() throws Exception { Library l=fixture();assertEquals("Prompts / GPT",l.categoryPath("22222222-2222-4222-8222-222222222222"));assertEquals(1,l.visible("favourites","").size());assertEquals(1,l.visible("all","世界").size()); }
    @Test public void editPreservesMetadataAndUsage() throws Exception {Library l=fixture();String id=l.phrases().get(0).getString("Id");l.used(id);l.savePhrase(id,"Edited","New","11111111-1111-4111-8111-111111111111",false);assertEquals(3,l.find(id).getInt("UseCount"));assertEquals("2026-10-01T12:00:00+00:00",l.find(id).getString("CreatedAt"));}
    @Test public void missingCategoryRejected() throws Exception {Library l=fixture();l.phrases().get(0).put("CategoryId","missing");assertThrows(JSONException.class,l::validate);}
    @Test public void cyclesRejected() throws Exception {Library l=fixture();l.categories().get(0).put("ParentId","22222222-2222-4222-8222-222222222222");assertThrows(JSONException.class,l::validate);}
    @Test public void duplicateIDsRejected() throws Exception {Library l=fixture();l.json.getJSONArray("Phrases").put(new JSONObject(l.phrases().get(0).toString()));assertThrows(JSONException.class,l::validate);}
    @Test public void unsupportedSchemaRejected() throws Exception {Library l=fixture();l.json.put("SchemaVersion",2);assertThrows(JSONException.class,l::validate);}
}
