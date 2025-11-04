// delete_user/index.ts
import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
serve(async (req)=>{
  try {
    // Only accept POST requests
    if (req.method !== "POST") {
      return new Response(JSON.stringify({
        error: "Method not allowed"
      }), {
        status: 405
      });
    }
    // Parse the JSON body
    const { user_id } = await req.json();
    if (!user_id) {
      return new Response(JSON.stringify({
        error: "Missing user_id"
      }), {
        status: 400
      });
    }
    // Get environment variables (these are the ones you created in the function settings)
    const SUPABASE_SERVICE_KEY = Deno.env.get("SERVICE_ROLE_KEY");
    const SUPABASE_URL = Deno.env.get("PROJECT_URL");
    if (!SUPABASE_SERVICE_KEY || !SUPABASE_URL) {
      return new Response(JSON.stringify({
        error: "Service key or project URL not set"
      }), {
        status: 500
      });
    }
    // Call the Supabase Admin API to delete the user
    const deleteResponse = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${user_id}`, {
      method: "DELETE",
      headers: {
        "apikey": SUPABASE_SERVICE_KEY,
        "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
        "Content-Type": "application/json"
      }
    });
    if (!deleteResponse.ok) {
      const errText = await deleteResponse.text();
      return new Response(JSON.stringify({
        error: `Failed to delete user: ${errText}`
      }), {
        status: 500
      });
    }
    return new Response(JSON.stringify({
      message: "User deleted successfully"
    }), {
      status: 200
    });
  } catch (err) {
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500
    });
  }
});
