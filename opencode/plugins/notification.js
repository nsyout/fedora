import { definePlugin } from "@opencode-ai/plugin";

export default definePlugin((api) => {
  const soundDir = `${process.env.HOME}/.config/opencode/sounds`;

  function playSound(file) {
    const path = `${soundDir}/${file}`;
    const { execSync } = require("child_process");
    try {
      execSync(`paplay "${path}" &`, { stdio: "ignore" });
    } catch {
      // paplay not available or sound file missing, ignore
    }
  }

  api.event.on("session.idle", (event) => {
    if (event.metadata?.subsession) return;
    playSound("notification.ogg");
  });

  api.event.on("permission.asked", (event) => {
    if (event.metadata?.subsession) return;
    playSound("notification.ogg");
  });
});
