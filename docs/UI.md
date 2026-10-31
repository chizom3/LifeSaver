# LifeSaver UI Guide

This document summarizes the current layout behavior for Android/mobile and web/desktop.

## Main App Shell

The top app bar uses the shorter title:

```text
LifeSaver
```

Only emergency mode stays as a direct action. Lower-priority actions such as Medical ID, refresh, test SOS, admin, disclaimer, privacy, data status, and report storage are in the overflow menu.

## Hospitals And Map Views

Hospitals and Map share the same responsive search/filter behavior.

### Mobile

- The hospital list or map appears immediately.
- A compact `Search` button opens filters in a draggable bottom sheet.
- Search/filter controls do not permanently push results down.

### Web/Desktop

- The hospital list or map appears immediately.
- A compact `Search` button opens filters as a left sidebar.
- The sidebar can be hidden again with `Hide filters`.

## Search And Filters

Filters include:

- Search by hospital, state, LGA, or ward.
- State dropdown.
- LGA dropdown.
- Saved hospitals.
- Nearest/A-Z sorting.
- Radius chips: Any, 5 km, 10 km, 25 km, 50 km.

The filter UI is compact to avoid wasting vertical space.

## SOS Button

The persistent SOS action is a compact red floating button. It is icon-only to reduce overlap with hospital cards and first aid content.

Hospital and First Aid lists include extra bottom padding so the SOS button and bottom navigation do not cover the final rows.

## First Aid

First Aid topics are grouped by category using expandable cards.

When the user searches, matching groups open automatically so results are visible.

## Medical ID

Medical ID uses expandable sections:

- Personal opens by default.
- Medical is collapsed by default.
- Emergency Contacts is collapsed by default.

In view mode, the profile photo field does not show raw local file paths. It shows whether a profile photo is saved on the device.

## Admin Sign In

Admin sign-in explains that admin users need a Firebase admin custom claim. Normal users do not need to sign in.
