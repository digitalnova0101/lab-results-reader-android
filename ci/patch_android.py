# Sets the app name and internet permission in the Android files Flutter generates.
import re, pathlib
m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = m.read_text()
s = re.sub(r'android:label="[^"]*"', 'android:label="Lab Results Reader"', s, count=1)
if "android.permission.INTERNET" not in s:
    s = re.sub(r'(<manifest[^>]*>)', r'\1\n    <uses-permission android:name="android.permission.INTERNET" />', s, count=1)
if "TTS_SERVICE" not in s:
    s = s.replace("</manifest>", """    <queries>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
    </queries>
</manifest>""")
m.write_text(s)
print(s[:600])

# Always sign the APK with the fixed key in keys/debug.keystore (SHA-1 06:6E:CF:22:...),
# so updates install over the old app and Google Sign-in matches the SHA-1 in Google Cloud.
g = pathlib.Path("android/app/build.gradle.kts")
if g.exists():
    t = g.read_text()
    if 'create("fixed")' not in t:
        t = t.replace("    buildTypes {", """    signingConfigs {
        create("fixed") {
            storeFile = file("../../keys/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {""", 1)
        t = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)', 'signingConfig = signingConfigs.getByName("fixed")', t)
        assert 'getByName("fixed")' in t, "could not set signing config"
    g.write_text(t)
else:
    g = pathlib.Path("android/app/build.gradle")
    t = g.read_text()
    if "fixed {" not in t:
        t = t.replace("    buildTypes {", """    signingConfigs {
        fixed {
            storeFile file("../../keys/debug.keystore")
            storePassword "android"
            keyAlias "androiddebugkey"
            keyPassword "android"
        }
    }

    buildTypes {""", 1)
        t = re.sub(r'signingConfig\s+signingConfigs\.debug', 'signingConfig signingConfigs.fixed', t)
        assert "signingConfigs.fixed" in t, "could not set signing config"
    g.write_text(t)
print("signing: fixed key")
# Fix package name for Google Play Console
g = pathlib.Path("android/app/build.gradle.kts")

if g.exists():
    t = g.read_text()
    t = re.sub(
        r'applicationId\s*=\s*"[^"]+"',
        'applicationId = "labresultsreader.com"',
        t
    )
    assert 'applicationId = "labresultsreader.com"' in t
    g.write_text(t)
else:
    g = pathlib.Path("android/app/build.gradle")
    t = g.read_text()
    t = re.sub(
        r'applicationId\s+["\'][^"\']+["\']',
        'applicationId "labresultsreader.com"',
        t
    )
    assert 'applicationId "labresultsreader.com"' in t
    g.write_text(t)

print("Package name: labresultsreader.com")
