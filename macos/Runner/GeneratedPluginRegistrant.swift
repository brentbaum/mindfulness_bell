import FlutterMacOS
import Foundation
import Cocoa

// This file is generated, do not edit
public func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  // Register the audioplayers_darwin plugin
  AudioplayersDarwinPlugin.register(with: registry.registrar(forPlugin: "AudioplayersDarwinPlugin"))
  // Register url_launcher_macos plugin
  UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
  
  // Note: FlashOverlayPlugin is now registered in MainFlutterWindow.swift
  NSLog("GeneratedPluginRegistrant: Standard plugins registered")
} 