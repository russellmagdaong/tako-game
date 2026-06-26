import { Stack, useRouter, useSegments } from "expo-router";
import { useEffect, useState } from "react";
import { supabase } from "../utils/supabase";

export default function RootLayout() {
  const router = useRouter();
  const segments = useSegments();
  const [authInitialized, setAuthInitialized] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setAuthInitialized(true);
      if (session) {
        // If user is on landing/login page, redirect to home
        const currentSegment = segments[0] || "";
        const isAuthScreen = currentSegment === "login" || currentSegment === "" || currentSegment === "index";
        if (isAuthScreen) {
          router.replace("/home");
        }
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (session) {
        const currentSegment = segments[0] || "";
        const isAuthScreen = currentSegment === "login" || currentSegment === "" || currentSegment === "index";
        if (isAuthScreen) {
          router.replace("/home");
        }
      } else {
        // If logged out, redirect to landing screen
        router.replace("/");
      }
    });

    return () => {
      subscription.unsubscribe();
    };
  }, [segments]);

  return <Stack screenOptions={{ headerShown: false }} />;
}