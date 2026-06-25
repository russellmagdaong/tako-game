import { useRouter } from "expo-router";
import { LinearGradient } from "expo-linear-gradient";
import * as ScreenOrientation from "expo-screen-orientation";
import { useEffect } from "react";
import { Platform, Pressable, SafeAreaView, StyleSheet, Text, View } from "react-native";

const routeNodes = ["1", "2", "3", "4", "5"] as const;

export default function GamePlaceholder() {
  const router = useRouter();

  useEffect(() => {
    if (Platform.OS === "web") {
      return;
    }

    void ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.LANDSCAPE);

    return () => {
      void ScreenOrientation.lockAsync(ScreenOrientation.OrientationLock.PORTRAIT_UP);
    };
  }, []);

  return (
    <LinearGradient colors={["#0f243d", "#1c5e5f", "#288342"]} style={styles.shell}>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.topBar}>
          <Pressable onPress={() => router.replace("/home")} style={({ pressed }) => [styles.backButton, pressed && styles.pressed]}>
            <Text style={styles.backText}>Back</Text>
          </Pressable>
          <View>
            <Text style={styles.title}>World Map</Text>
            <Text style={styles.subtitle}>Landscape game placeholder</Text>
          </View>
        </View>

        <View style={styles.stage}>
          <LinearGradient colors={["#213c71", "#2a8d72", "#f2b75a"]} style={styles.map}>
            <View style={styles.sun} />
            <View style={styles.cloudOne} />
            <View style={styles.cloudTwo} />
            <View style={styles.mountainBack} />
            <View style={styles.mountainFront} />
            <View style={styles.route} />
            {routeNodes.map((node, index) => (
              <View key={node} style={[styles.routeNode, { left: `${12 + index * 18}%`, top: `${60 - (index % 2) * 18}%` }]}>
                <Text style={styles.routeNodeText}>{node}</Text>
              </View>
            ))}
          </LinearGradient>
        </View>

        <View style={styles.footerPanel}>
          <Text style={styles.footerTitle}>Game scene coming soon</Text>
          <Text style={styles.footerCopy}>
            This route is ready for the playable landscape world map once the game module is added.
          </Text>
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
    padding: 16,
    gap: 14,
  },
  topBar: {
    flexDirection: "row",
    alignItems: "center",
    gap: 14,
  },
  backButton: {
    minWidth: 72,
    minHeight: 42,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(255,255,255,0.16)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.28)",
  },
  backText: {
    color: "#ffffff",
    fontSize: 13,
    fontWeight: "900",
  },
  title: {
    color: "#ffffff",
    fontSize: 24,
    lineHeight: 28,
    fontWeight: "900",
  },
  subtitle: {
    color: "#b7d5e3",
    fontSize: 12,
    lineHeight: 16,
    fontWeight: "700",
  },
  stage: {
    flex: 1,
    minHeight: 220,
    justifyContent: "center",
  },
  map: {
    width: "100%",
    aspectRatio: 16 / 9,
    borderRadius: 20,
    overflow: "hidden",
    borderWidth: 4,
    borderColor: "#f4cf62",
    shadowColor: "#000",
    shadowOpacity: 0.25,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 10 },
    elevation: 6,
  },
  sun: {
    position: "absolute",
    top: 24,
    right: 34,
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: "#ffd65f",
  },
  cloudOne: {
    position: "absolute",
    top: 38,
    left: 42,
    width: 94,
    height: 22,
    borderRadius: 12,
    backgroundColor: "rgba(255,255,255,0.34)",
  },
  cloudTwo: {
    position: "absolute",
    top: 70,
    right: 110,
    width: 74,
    height: 18,
    borderRadius: 10,
    backgroundColor: "rgba(255,255,255,0.26)",
  },
  mountainBack: {
    position: "absolute",
    left: -20,
    bottom: 58,
    width: "58%",
    height: "44%",
    borderTopLeftRadius: 120,
    borderTopRightRadius: 120,
    backgroundColor: "#304d66",
    transform: [{ rotate: "-7deg" }],
  },
  mountainFront: {
    position: "absolute",
    right: -28,
    bottom: 44,
    width: "68%",
    height: "50%",
    borderTopLeftRadius: 130,
    borderTopRightRadius: 130,
    backgroundColor: "#1e4256",
    transform: [{ rotate: "6deg" }],
  },
  route: {
    position: "absolute",
    left: "9%",
    right: "8%",
    bottom: "24%",
    height: 22,
    borderRadius: 999,
    backgroundColor: "#f1d39a",
    transform: [{ rotate: "-5deg" }],
  },
  routeNode: {
    position: "absolute",
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#ffd24a",
    borderWidth: 4,
    borderColor: "#ff7d00",
  },
  routeNodeText: {
    color: "#3a2700",
    fontSize: 14,
    fontWeight: "900",
  },
  footerPanel: {
    borderRadius: 16,
    padding: 16,
    backgroundColor: "rgba(255,255,255,0.14)",
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.22)",
  },
  footerTitle: {
    color: "#ffffff",
    fontSize: 17,
    fontWeight: "900",
  },
  footerCopy: {
    marginTop: 4,
    color: "#c9dde8",
    fontSize: 12,
    lineHeight: 18,
    fontWeight: "700",
  },
  pressed: {
    opacity: 0.82,
    transform: [{ scale: 0.98 }],
  },
});
