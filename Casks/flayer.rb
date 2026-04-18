# Template Homebrew Cask for FlaYer.
#
# Copy this file into your own tap repository (e.g. `homebrew-flayer`)
# under `Casks/flayer.rb` and edit the three ALL-CAPS placeholders:
#
#   1. VERSION_PLACEHOLDER — match the git tag / DMG filename
#   2. SHA256_PLACEHOLDER  — run `shasum -a 256` on the released DMG
#   3. GH_OWNER            — your GitHub username / org
#
# Users then install with:
#   brew tap GH_OWNER/flayer
#   brew install --cask flayer
#
# The postflight block strips the com.apple.quarantine attribute so
# Gatekeeper does not block the ad-hoc-signed binary. Without it the
# user would have to right-click → Open on first launch.

cask "flayer" do
  version "VERSION_PLACEHOLDER"
  sha256 "SHA256_PLACEHOLDER"

  url "https://github.com/GH_OWNER/flayer/releases/download/v#{version}/FlaYer-#{version}.dmg"
  name "FlaYer"
  desc "Native macOS music player for audiophiles"
  homepage "https://github.com/GH_OWNER/flayer"

  depends_on macos: ">= :sonoma"

  app "FlaYer.app"

  postflight do
    # The DMG is ad-hoc signed (no paid Apple Developer account), so Gatekeeper
    # would refuse to launch it with "cannot be opened because Apple cannot
    # verify it is free of malware." Homebrew Cask is trusted to strip the
    # quarantine bit on its managed apps — this turns brew install into a
    # one-step flow.
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/FlaYer.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/FlaYer",
    "~/Library/Caches/CoverArt",
    "~/Library/Containers/com.flayer.macos",
    "~/Library/Group Containers/group.com.flayer",
    "~/Library/Preferences/com.flayer.macos.plist",
  ]
end
