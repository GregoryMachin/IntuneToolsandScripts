**Configure notification of update and deadline to enforce the update.**

Below are the **exact clicks to recreate the policy you built in Settings Catalog for every Windows device you manage with Intune —including servers**.
(These steps use only the **native Settings-catalog / Administrative-templates blades**—no custom OMA-URI or ADMX-import is needed.)

---

## 1  Create one profile for both browsers

1. **Microsoft Intune admin center**
   → **Devices ▶ Configuration profiles ▶ Create profile**
2. **Platform**   : **Windows 10 and later** *(covers Windows 10/11 and Windows Server 2016/2019/2022 when enrolled in MDM)*
   **Profile type** : **Settings catalog**
3. **Name** : “Browser Updates – 5-Day / 00-09 Window” → **Next**

---

## 2  Add the Chrome settings

1. On **Configuration settings** page click **+ Add settings**
2. **Search** : `Relaunch` → expand **Google ▶ Google Chrome ▶ Update**.
3. Tick **four** device-scope rows, then click **Select**:

| Setting                                                                                         | Configuration                                                                                |
| ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **Notify a user that a browser relaunch or device restart is recommended or required (Device)** | **Enabled** → **Show a recurring prompt … relaunch is *required***                           |
| **Set the time period for update notifications (Device)**                                       | **Enabled** → **432000000**                                                                  |
| **Set the time interval for relaunch (Device)**                                                 | **Enabled** → paste →<br>`{"entries":[{"start":{"hour":0,"minute":0},"duration_mins":540}]}` |
| *(optional)* **Update policy override default** (Google Update ▶ Applications)                  | **Enabled** → **Always allow updates (recommended)**                                         |

> *Tip:* clear the corresponding **user-scope** rows (if visible) to avoid duplicates.

---

## 3  Add the Edge settings

1. Click **+ Add settings** again → search `Relaunch` → expand
   **Microsoft Edge ▶ Update**.
2. Tick these **three** device-scope rows:

| Setting                                                                                          | Configuration                                                                                          |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| **Notify a user that a browser restart is recommended or required for pending updates (Device)** | **Enabled** → **Required – Show a recurring prompt**                                                   |
| **Set the time period for update notifications (Device)**                                        | **Enabled** → **432000000**                                                                            |
| **Set the time interval for relaunch (Device)**                                                  | **Enabled** → same JSON window:<br>`{"entries":[{"start":{"hour":0,"minute":0},"duration_mins":540}]}` |

3. Still in **Add settings** search `Update policy override default` → expand
   **Microsoft Edge Update ▶ Applications** → tick **Update policy override default (Device)**
   *Set to* **Enabled** → **Always allow updates (recommended)**.

---

## 4  Assignments & scope

1. **Next** to **Assignments** → add your **device groups**.
   *Include servers* (they honour the same policies when enrolled in Intune).
2. **Next** through **Applicability / Scope tags** → **Review + create** → **Create**.

Intune writes the required registry keys on every target machine at the next MDM sync.

---

## 5  Validate on a device

| Browser | Check                               | Expected values                                                                                                                                              |
| ------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Chrome  | `chrome://policy` → Reload policies | `RelaunchNotification = 2` · `RelaunchNotificationPeriod = 432000000` · `RelaunchWindow = {"entries":[{"start":{"hour":0,"minute":0},"duration_mins":540}]}` |
| Edge    | `edge://policy` → Reload policies   | Same three keys with identical values                                                                                                                        |

Status column should be **OK**.

---

### What your servers & PCs will now do

* **Download & install updates silently** (Google / Edge Update services always allowed).
* **Display a “Restart required” banner immediately** after install.
* **Give users 5 days** to restart themselves.
* **Auto-restart only between 00:00-09:00** the next time the browser is running after the deadline—no surprise restarts during business hours.

That’s it—the Intune-native profile replicates your earlier Settings-catalog build across every Windows client and server you enrol.
