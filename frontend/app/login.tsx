import { useRouter } from "expo-router";
import { LinearGradient } from "expo-linear-gradient";
import * as ScreenOrientation from "expo-screen-orientation";
import { useEffect, useState } from "react";
import { Platform, Pressable, SafeAreaView, StyleSheet, Text, TextInput, View } from "react-native";

export default function LoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<"signin" | "signup">("signin");

  useEffect(() => {
    if (Platform.OS !== "web") {
      void ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.PORTRAIT_UP);
    }
  }, []);

  return (
    <LinearGradient colors={["#0a1120", "#1f2f9d", "#0d7b9e"]} style={styles.shell}>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.container}>
          <View style={styles.brandHeader}>
            <View style={styles.logoPlate}>
              <Text style={styles.logoText}>TAKO</Text>
            </View>
            <Text style={styles.subtitle}>MathQuest AI</Text>
          </View>

          <View style={styles.formCard}>
            <View style={styles.tabRow}>
              <Pressable
                onPress={() => setMode("signin")}
                style={[styles.tab, mode === "signin" ? styles.tabActive : styles.tabInactive]}
              >
                <Text style={[styles.tabText, mode === "signin" ? styles.tabTextActive : styles.tabTextInactive]}>
                  Sign In
                </Text>
              </Pressable>
              <Pressable
                onPress={() => setMode("signup")}
                style={[styles.tab, mode === "signup" ? styles.tabActive : styles.tabInactive]}
              >
                <Text style={[styles.tabText, mode === "signup" ? styles.tabTextActive : styles.tabTextInactive]}>
                  Sign Up
                </Text>
              </Pressable>
            </View>

            <View style={styles.avatarWrap}>
              <View style={styles.avatar}>
                <Text style={styles.avatarText}>TA</Text>
              </View>
            </View>

            <View style={styles.fieldGroup}>
              <Text style={styles.label}>Email</Text>
              <TextInput
                autoCapitalize="none"
                keyboardType="email-address"
                placeholder="trainer@tako.ph"
                placeholderTextColor="#93a8c6"
                style={styles.input}
              />
            </View>

            <View style={styles.fieldGroup}>
              <Text style={styles.label}>Password</Text>
              <TextInput
                placeholder="Password"
                placeholderTextColor="#93a8c6"
                secureTextEntry
                style={styles.input}
              />
            </View>

            <Pressable
              onPress={() => router.replace("/home")}
              style={({ pressed }) => [styles.submitButton, pressed && styles.pressed]}
            >
              <Text style={styles.submitButtonText}>{mode === "signin" ? "Sign In" : "Create Account"}</Text>
            </Pressable>
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
  container: {
    flex: 1,
    justifyContent: "center",
    paddingHorizontal: 18,
    paddingBottom: 28,
    gap: 24,
  },
  brandHeader: {
    alignItems: "center",
    gap: 10,
  },
  logoPlate: {
    minWidth: 178,
    minHeight: 82,
    borderRadius: 24,
    borderWidth: 4,
    borderColor: "#ffd746",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#24346f",
    shadowColor: "#000",
    shadowOpacity: 0.22,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 5,
  },
  logoText: {
    color: "#ffd746",
    fontSize: 40,
    lineHeight: 44,
    fontWeight: "900",
  },
  subtitle: {
    color: "#e9f2ff",
    fontSize: 17,
    fontWeight: "900",
    letterSpacing: 0.8,
  },
  formCard: {
    backgroundColor: "#f7f7fb",
    borderRadius: 24,
    overflow: "hidden",
    shadowColor: "#000",
    shadowOpacity: 0.18,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
    elevation: 6,
  },
  tabRow: {
    flexDirection: "row",
    backgroundColor: "#f2f2f7",
  },
  tab: {
    flex: 1,
    minHeight: 50,
    alignItems: "center",
    justifyContent: "center",
    borderBottomWidth: 3,
  },
  tabActive: {
    backgroundColor: "#fff7dc",
    borderBottomColor: "#ffd24a",
  },
  tabInactive: {
    backgroundColor: "#f2f2f7",
    borderBottomColor: "#e0e3ec",
  },
  tabText: {
    fontSize: 15,
    fontWeight: "900",
  },
  tabTextActive: {
    color: "#0d1530",
  },
  tabTextInactive: {
    color: "#8c9bb9",
  },
  avatarWrap: {
    alignItems: "center",
    paddingTop: 22,
    paddingBottom: 12,
  },
  avatar: {
    width: 62,
    height: 62,
    borderRadius: 17,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#ffb31f",
  },
  avatarText: {
    color: "#2f8a45",
    fontSize: 17,
    fontWeight: "900",
    letterSpacing: 1,
  },
  fieldGroup: {
    paddingHorizontal: 18,
    paddingBottom: 12,
    gap: 8,
  },
  label: {
    color: "#7d91b1",
    fontSize: 12,
    fontWeight: "900",
    letterSpacing: 0.6,
  },
  input: {
    minHeight: 50,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "#d5dbe3",
    backgroundColor: "#eef1f4",
    color: "#22314a",
    fontSize: 15,
    fontWeight: "700",
    paddingHorizontal: 16,
  },
  submitButton: {
    marginHorizontal: 18,
    marginTop: 4,
    marginBottom: 20,
    minHeight: 58,
    borderRadius: 19,
    borderWidth: 3,
    borderColor: "#ff7d00",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#ffd24a",
  },
  submitButtonText: {
    color: "#201600",
    fontSize: 18,
    fontWeight: "900",
  },
  pressed: {
    opacity: 0.84,
    transform: [{ scale: 0.98 }],
  },
});
