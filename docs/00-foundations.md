# 0. Design Foundations

## 0.1 Color (semantic)

* bg: systemBackground / secondarySystemBackground
* text-primary: label
* text-secondary: secondaryLabel
* accent: tint
* danger: systemRed
* success: systemGreen
* warning: systemOrange

## 0.2 Typography (SF Pro; iOS 17+)

* display: 28/34, semibold
* title: 22/28, semibold
* body: 17/22, regular
* caption: 13/16, regular
* mono: 15/20, regular (for codes/timers)

## 0.3 Spacing (8pt grid)

* xs: 4, sm: 8, md: 12, lg: 16, xl: 24, 2xl: 32

## 0.4 Radius & Elevation

* radius: 12 (cards), 8 (controls)
* shadow: subtle for cards; none on list rows

## 0.5 States

* focus-ring: system-defined
* error: danger text + subtle bg tint
* disabled: 60% opacity on text + no shadow

## 0.6 Iconography

* SF Symbols only. Stroke where possible; min tap target 44pt.

## 0.7 Reliability Principles

* Local notifications are the **primary ringer** and must always be scheduled as the OS-guaranteed sound source.
* Audio sessions are an **enhancement**: when the app is active, start continuous playback to improve the user experience.
* Foreground notifications must suppress `.sound` when audio is actively ringing to avoid double audio.
* If the audio session is killed by iOS, notifications still guarantee the alarm fires with sound.
