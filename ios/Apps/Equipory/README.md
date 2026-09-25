# Equipory iOS

Working product name: **Equipory**

**Every machine remembers.**

Equipory is the premium iOS product built on top of EdgeFrameworks.

## MVP navigation

Equipment
→ Add / Scan Equipment
→ Equipment Workspace
→ Ask / Sources / Service History / Photos

The first skeleton intentionally uses a lightweight in-memory equipment store so the
product flow can stabilize before persistence and camera/OCR are introduced.

Each EquipmentAsset maps to an EdgeKnowledgeCollection. That keeps the product model
aligned with the framework's collection-scoped local knowledge and RAG architecture.

## Generate the Xcode project

From ios/Apps/Equipory:

    xcodegen generate
    open Equipory.xcodeproj

Requirements:

- Xcode 26+
- iOS 26+
- XcodeGen
