# APK Signing Instructions

To ensure that APK updates install normally over previous versions, both the User App and Admin App must be signed with the same consistent release keystore.

## Generating the Keystore

1. Open your terminal.
2. Navigate to your project directory:
   ```powershell
   cd "C:\Users\KOMALPRRET\Desktop\esport"
   ```
3. Run the following command to generate the release keystore:

```bash
![alt text](image.png)
```

**Note:** You should copy this same keystore file to `esport_admin_app/android/app/` as well.

### File Locations:
- `esport_user_app/android/app/esportadda-release.keystore`
- `esport_admin_app/android/app/esportadda-release.keystore`

## Local Configuration

Create a `key.properties` file in `esport_user_app/android/` and `esport_admin_app/android/`.
**This file is ignored by Git and should never be committed.**

### Example `key.properties`:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=esportadda
storeFile=esportadda-release.keystore
```

## GitHub Actions Configuration

1. Convert your keystore file to Base64:
   ```bash
   base64 -w 0 esportadda-release.keystore > keystore_base64.txt
   ```
2. Add the following Secrets to your GitHub Repository settings:
   - `KEYSTORE_BASE64`: The content of `keystore_base64.txt`.
   - `KEYSTORE_PASSWORD`: Your keystore store password.
   - `KEY_PASSWORD`: Your key password.
   - `KEY_ALIAS`: `esportadda`
