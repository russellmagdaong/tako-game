import { useRouter } from "expo-router";
import { LinearGradient } from "expo-linear-gradient";
import * as ScreenOrientation from "expo-screen-orientation";
import { useEffect, useState } from "react";
import { ActivityIndicator, Platform, Pressable, SafeAreaView, StyleSheet, Text, View } from "react-native";
import { supabase } from "../utils/supabase";

export default function MainLandingPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (Platform.OS !== "web") {
      void ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.PORTRAIT_UP);
    }
  }, []);

  const handlePlayAsGuest = async () => {
    if (loading) return;
    setLoading(true);
    try {
      const { error } = await supabase.auth.signInAnonymously();
      if (error) {
        alert("Guest login failed: " + error.message);
      } else {
        router.replace("/home");
      }
    } catch (err: any) {
      alert("An unexpected error occurred: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <LinearGradient colors={["#081027", "#2430a6", "#0b789f"]} style={styles.shell}>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.screen}>
          <View style={styles.logoCard}>
            <Text style={styles.logoText}>TAKO</Text>
          </View>

          <View style={styles.actionStack}>
            <Pressable
              disabled={loading}
              onPress={() => router.push("/login")}
              style={({ pressed }) => [styles.primaryButton, pressed && styles.pressed]}
            >
              <Text style={styles.primaryButtonText}>Sign In / Sign Up</Text>
            </Pressable>
            <Pressable
              disabled={loading}
              onPress={handlePlayAsGuest}
              style={({ pressed }) => [styles.guestButton, pressed && styles.pressed]}
            >
              {loading ? (
                <ActivityIndicator color="#ffffff" />
              ) : (
                <Text style={styles.guestButtonText}>Play as Guest</Text>
              )}
            </Pressable>
          </View>

          <View style={styles.footer}>
            <View style={styles.footerDot} />
            <Text style={styles.footerText}>MATHQUEST AI - PROTOTYPE</Text>
          </View>
        </View>
      </SafeAreaView>
    </LinearGradient>
  );
}

const styles = StyleSheet.create({
  shell: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
  },
  screen: {
    flex: 1,
    justifyContent: "center",
    paddingHorizontal: 28,
    gap: 84,
  },
  logoCard: {
    minHeight: 132,
    borderRadius: 24,
    borderWidth: 3,
    borderColor: "#ffd746",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(255,255,255,0.08)",
    shadowColor: "#000",
    shadowOpacity: 0.24,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 10 },
    elevation: 6,
  },
  logoText: {
    color: "#ffd746",
    fontSize: 46,
    lineHeight: 50,
    fontWeight: "900",
  },
  logoSubtext: {
    marginTop: 6,
    color: "#eaf4ff",
    fontSize: 14,
    fontWeight: "900",
    letterSpacing: 0.8,
  },
  actionStack: {
    gap: 28,
  },
  primaryButton: {
    minHeight: 64,
    borderRadius: 18,
    borderWidth: 3,
    borderColor: "#ff7d00",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#ffd24a",
    shadowColor: "#000",
    shadowOpacity: 0.18,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 7 },
    elevation: 5,
  },
  primaryButtonText: {
    color: "#201600",
    fontSize: 18,
    fontWeight: "900",
  },
  guestButton: {
    minHeight: 64,
    borderRadius: 18,
    borderWidth: 2,
    borderColor: "rgba(255,255,255,0.62)",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(255,255,255,0.12)",
  },
  guestButtonText: {
    color: "#ffffff",
    fontSize: 18,
    fontWeight: "900",
  },
  footer: {
    position: "absolute",
    bottom: 18,
    alignSelf: "center",
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  footerDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: "#18d07a",
  },
  footerText: {
    color: "#9bb1c9",
    fontSize: 11,
    fontWeight: "800",
    letterSpacing: 1.2,
  },
  pressed: {
    opacity: 0.84,
    transform: [{ scale: 0.98 }],
  },
});
