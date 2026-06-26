import "react-native-url-polyfill/auto";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL ?? "";
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? "";

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});

// Offline testing fallback: Wrap auth methods to return a dummy session/user if local/remote Supabase is unreachable
const originalSignInAnonymously = supabase.auth.signInAnonymously.bind(supabase.auth);
const originalGetSession = supabase.auth.getSession.bind(supabase.auth);
const originalGetUser = supabase.auth.getUser.bind(supabase.auth);

const dummyUser = {
  id: "d000d000-d000-d000-d000-d000d000d000",
  email: "guest@example.com",
  role: "authenticated",
  aud: "authenticated",
  app_metadata: {},
  user_metadata: {},
  created_at: new Date().toISOString(),
};

const dummySession = {
  access_token: "dummy-offline-token",
  token_type: "bearer",
  expires_in: 3600,
  refresh_token: "dummy-offline-refresh-token",
  user: dummyUser,
};

let currentSession: any = null;
const listeners = new Set<(event: string, session: any) => void>();

supabase.auth.onAuthStateChange = (callback: any) => {
  listeners.add(callback);
  // Trigger callback immediately with the current session state
  callback(currentSession ? "SIGNED_IN" : "SIGNED_OUT", currentSession);
  return {
    data: {
      subscription: {
        unsubscribe: () => {
          listeners.delete(callback);
        },
      },
    },
  };
};

supabase.auth.signInAnonymously = async (options?: any) => {
  try {
    const res = await originalSignInAnonymously(options);
    if (res.error) {
      currentSession = dummySession;
      listeners.forEach(cb => cb("SIGNED_IN", dummySession));
      return { data: { session: dummySession, user: dummyUser }, error: null };
    }
    currentSession = res.data.session;
    listeners.forEach(cb => cb("SIGNED_IN", currentSession));
    return res;
  } catch {
    currentSession = dummySession;
    listeners.forEach(cb => cb("SIGNED_IN", dummySession));
    return { data: { session: dummySession, user: dummyUser }, error: null };
  }
};

supabase.auth.getSession = async () => {
  if (currentSession) {
    return { data: { session: currentSession }, error: null };
  }
  try {
    const res = await originalGetSession();
    if (res.data.session) {
      currentSession = res.data.session;
    }
    return res;
  } catch {
    return { data: { session: null }, error: null };
  }
};

supabase.auth.getUser = async (jwt?: string) => {
  if (currentSession) {
    return { data: { user: currentSession.user }, error: null };
  }
  try {
    const res = await originalGetUser(jwt);
    return res;
  } catch {
    return { data: { user: null }, error: null };
  }
};

// Also mock signOut to clear currentSession and trigger callbacks
const originalSignOut = supabase.auth.signOut.bind(supabase.auth);
supabase.auth.signOut = async () => {
  currentSession = null;
  listeners.forEach(cb => cb("SIGNED_OUT", null));
  try {
    return await originalSignOut();
  } catch {
    return { error: null };
  }
};


