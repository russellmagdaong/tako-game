import { LinearGradient } from "expo-linear-gradient";
import { Pressable, SafeAreaView, StyleSheet, Text, View } from "react-native";

const stars = [
  { top: "8%", left: "12%", size: 4, opacity: 0.55 },
  { top: "18%", left: "74%", size: 3, opacity: 0.5 },
  { top: "30%", left: "19%", size: 5, opacity: 0.45 },
  { top: "42%", left: "88%", size: 3, opacity: 0.55 },
  { top: "73%", left: "82%", size: 4, opacity: 0.45 },
] as const;

const towers = ["13%", "37%", "63%", "84%"] as const;

export function LandingScreen({ onStart }: { onStart: () => void }) {
  return (
    <LinearGradient colors={["#1f2878", "#26318a", "#18256b"]} style={styles.shell}>
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.screen}>
          {stars.map((star, index) => (
            <View
              key={index}
              style={[
                styles.star,
                {
                  top: star.top,
                  left: star.left,
                  width: star.size,
                  height: star.size,
                  opacity: star.opacity,
                },
              ]}
            />
          ))}

          <View style={styles.hero}>
            <View style={[styles.enemyBlock, styles.enemyGreen]}>
              <View style={styles.enemyEye} />
            </View>
            <View style={styles.logoPlate}>
              <Text style={styles.logoText}>TAKO</Text>
            </View>
            <View style={[styles.enemyBlock, styles.enemyRed]}>
              <View style={styles.enemyEye} />
            </View>
          </View>

          <Text style={styles.copy}>
            Explore story-driven grade halls, answer questions, and get AI-guided explanations in English or Filipino.
          </Text>

          <Pressable onPress={onStart} style={({ pressed }) => [styles.startButton, pressed && styles.pressed]}>
            <Text style={styles.startText}>{">"} Start Adventure</Text>
          </Pressable>

          <View style={styles.ground}>
            <View style={styles.groundTrim} />
            {towers.map((left, index) => (
              <View key={index} style={[styles.tower, { left }]}>
                <View style={styles.towerTop} />
                <View style={styles.towerBody} />
              </View>
            ))}
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
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 24,
    paddingBottom: 126,
  },
  star: {
    position: "absolute",
    borderRadius: 2,
    backgroundColor: "#f5d868",
  },
  hero: {
    width: "100%",
    maxWidth: 360,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 12,
  },
  logoPlate: {
    flex: 1,
    minHeight: 96,
    borderRadius: 28,
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
    fontSize: 42,
    lineHeight: 46,
    fontWeight: "900",
  },
  enemyBlock: {
    width: 62,
    height: 62,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 3,
    shadowColor: "#000",
    shadowOpacity: 0.22,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 6 },
    elevation: 4,
  },
  enemyGreen: {
    backgroundColor: "#48bd67",
    borderColor: "#6ee486",
  },
  enemyRed: {
    backgroundColor: "#eb6049",
    borderColor: "#ff8b62",
  },
  enemyEye: {
    width: 10,
    height: 10,
    borderRadius: 2,
    backgroundColor: "#f6f7ff",
  },
  copy: {
    marginTop: 32,
    maxWidth: 330,
    color: "#f4f7ff",
    fontSize: 19,
    lineHeight: 30,
    fontWeight: "600",
    textAlign: "center",
  },
  startButton: {
    marginTop: 34,
    width: "100%",
    maxWidth: 330,
    minHeight: 74,
    borderRadius: 25,
    borderWidth: 4,
    borderColor: "#ff7d00",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#f3cf55",
    shadowColor: "#000",
    shadowOpacity: 0.2,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 8 },
    elevation: 5,
  },
  startText: {
    color: "#201600",
    fontSize: 22,
    lineHeight: 26,
    fontWeight: "900",
  },
  ground: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    height: 132,
    backgroundColor: "#257b35",
  },
  groundTrim: {
    position: "absolute",
    left: 0,
    right: 0,
    top: 0,
    height: 10,
    backgroundColor: "#f0ede8",
    borderBottomWidth: 3,
    borderBottomColor: "#d6d2ca",
  },
  tower: {
    position: "absolute",
    bottom: 16,
    width: 42,
    alignItems: "center",
  },
  towerTop: {
    width: 38,
    height: 18,
    borderRadius: 3,
    backgroundColor: "#19c467",
  },
  towerBody: {
    width: 26,
    height: 78,
    backgroundColor: "#13df79",
  },
  pressed: {
    opacity: 0.86,
    transform: [{ scale: 0.98 }],
  },
});
