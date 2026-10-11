import { defineConfig } from "vitepress";

// Docs are served under exoharness.ai/docs by the Cloudflare Worker in
// website/. `vitepress build` emits static files straight into website/dist/docs
// (outDir below), which the Worker serves as plain assets — no nested install,
// no separate deploy.
export default defineConfig({
  base: "/docs/",
  outDir: "../dist/docs",
  cleanUrls: true,
  lang: "en",
  title: "exo docs",
  description: "Documentation for exo — a minimal system for building agents.",
  appearance: "dark",
  head: [
    ["link", { rel: "icon", type: "image/svg+xml", href: "/favicon.svg" }],
  ],
  themeConfig: {
    logo: {
      light: "/images/exo-badge-light.svg",
      dark: "/images/exo-badge-dark.svg",
    },
    siteTitle: "exo",
    nav: [
      { text: "Docs", link: "/" },
      { text: "Archive", link: "/archive/" },
      { text: "GitHub", link: "https://github.com/exoharness/exo" },
    ],
    search: { provider: "local" },
    socialLinks: [{ icon: "github", link: "https://github.com/exoharness/exo" }],
    sidebar: {
      "/archive/": [
        { text: "Current docs", link: "/" },
        { text: "Archive", link: "/archive/" },
        { text: "Earlier overview", link: "/archive/overview" },
        {
          text: "Getting started",
          link: "/archive/getting-started/",
          collapsed: true,
          items: [
            {
              text: "Installation",
              link: "/archive/getting-started/installation",
            },
            {
              text: "Your first session",
              link: "/archive/getting-started/first-session",
            },
            {
              text: "Using the CLI directly",
              link: "/archive/getting-started/quick-start",
            },
            {
              text: "A sandboxed conversation",
              link: "/archive/getting-started/sandboxed-conversation",
            },
          ],
        },
        {
          text: "Concepts",
          link: "/archive/concepts/",
          collapsed: true,
          items: [
            {
              text: "Self-agent lifecycles",
              link: "/archive/concepts/lifecycles",
            },
            { text: "Self-agent tools", link: "/archive/concepts/tools" },
            { text: "Adapters", link: "/archive/concepts/adapters" },
            {
              text: "Task scheduler",
              link: "/archive/concepts/task-scheduler",
            },
            {
              text: "The canonical agent",
              link: "/archive/concepts/canonical-agent",
            },
          ],
        },
      ],
      "/": [
        { text: "Overview", link: "/" },
        { text: "Agent definition", link: "/agent-definition" },
        {
          text: "Tutorials",
          link: "/tutorials/",
          collapsed: false,
          items: [
            { text: "Support agent", link: "/tutorials/support-agent" },
            {
              text: "Custom harness",
              link: "/tutorials/write-your-own-agent",
            },
            {
              text: "Custom coding agent",
              link: "/tutorials/custom-coding-agent",
            },
            {
              text: "Game integration",
              link: "/tutorials/game-emulator-integration",
            },
          ],
        },
        {
          text: "Architecture",
          link: "/concepts/",
          collapsed: true,
          items: [
            {
              text: "Exoharness & executor",
              link: "/concepts/exoharness-and-executor",
            },
            { text: "Data model", link: "/reference/data-model" },
            { text: "Harnesses", link: "/reference/harnesses" },
            { text: "Lifecycles", link: "/concepts/lifecycles" },
            { text: "Sandboxes", link: "/concepts/sandboxes" },
            { text: "Forks and snapshots", link: "/concepts/time-travel" },
            {
              text: "Vaults and credentials",
              link: "/concepts/bindings-and-secrets",
            },
            { text: "Tools", link: "/concepts/tools" },
          ],
        },
        { text: "Development", link: "/development/" },
      ],
    },
  },
});
