package com.labresultsreader.app;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.MediaStore;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import androidx.core.content.FileProvider;

import java.io.File;

/**
 * Lab Results Reader Android app: opens your hosted web app (app_url in res/values/strings.xml)
 * and supports photo upload, PDF upload and the camera.
 */
public class MainActivity extends Activity {

    private static final int REQ_FILES = 1001;
    private static final String BG = "#F2F5F4";

    private WebView webView;
    private ValueCallback<Uri[]> filePathCallback;
    private Uri cameraUri;
    private String appUrl;
    private String appHost;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        appUrl = getString(R.string.app_url);
        appHost = Uri.parse(appUrl).getHost();

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.parseColor(BG));
        webView = new WebView(this);
        webView.setBackgroundColor(Color.parseColor(BG));
        root.addView(webView, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);

        // Keep content clear of the status bar and navigation bar (Android 15 draws edge to edge)
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            int top, bottom, left, right;
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets i = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.ime());
                top = i.top; bottom = i.bottom; left = i.left; right = i.right;
            } else {
                top = insets.getSystemWindowInsetTop(); bottom = insets.getSystemWindowInsetBottom();
                left = insets.getSystemWindowInsetLeft(); right = insets.getSystemWindowInsetRight();
            }
            v.setPadding(left, top, right, bottom);
            return insets;
        });
        if (Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) c.setSystemBarsAppearance(
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS,
                    WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS);
        }

        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);          // keeps history and settings on the phone
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);
        s.setMediaPlaybackRequiresUserGesture(true);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        s.setUserAgentString(s.getUserAgentString() + " LabResultsReaderAndroid/1.5");

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri u = request.getUrl();
                if (appHost != null && appHost.equalsIgnoreCase(u.getHost())) return false;
                // Other websites, email and phone links open outside the app
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception ignored) {}
                return true;
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) showOffline();
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (filePathCallback != null) filePathCallback.onReceiveValue(null);
                filePathCallback = callback;
                Intent camera = cameraIntent();

                // <input capture> = "Take a photo" button: open the camera directly
                if (params.isCaptureEnabled() && camera != null) {
                    try { startActivityForResult(camera, REQ_FILES); return true; }
                    catch (Exception e) { /* fall through to the picker */ }
                }

                Intent pick = new Intent(Intent.ACTION_GET_CONTENT);
                pick.addCategory(Intent.CATEGORY_OPENABLE);
                pick.setType("*/*");
                pick.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"image/*", "application/pdf"});
                pick.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, params.getMode() == FileChooserParams.MODE_OPEN_MULTIPLE);
                Intent chooser = Intent.createChooser(pick, "Add your report");
                if (camera != null) chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, new Intent[]{camera});
                try {
                    startActivityForResult(chooser, REQ_FILES);
                } catch (Exception e) {
                    filePathCallback = null;
                    return false;
                }
                return true;
            }
        });

        if (savedInstanceState != null) {
            webView.restoreState(savedInstanceState);
        } else {
            // Always load the latest website version (no stale copy from an old visit)
            webView.clearCache(true);
            webView.loadUrl(appUrl);
        }
    }

    private Intent cameraIntent() {
        try {
            File dir = new File(getCacheDir(), "camera");
            if (!dir.exists() && !dir.mkdirs()) return null;
            File photo = new File(dir, "report_" + System.currentTimeMillis() + ".jpg");
            cameraUri = FileProvider.getUriForFile(this, getPackageName() + ".fileprovider", photo);
            Intent i = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            i.putExtra(MediaStore.EXTRA_OUTPUT, cameraUri);
            i.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            return i;
        } catch (Exception e) {
            cameraUri = null;
            return null;
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_FILES || filePathCallback == null) return;
        Uri[] results = null;
        if (resultCode == RESULT_OK) {
            ClipData clip = data != null ? data.getClipData() : null;
            if (clip != null && clip.getItemCount() > 0) {
                results = new Uri[clip.getItemCount()];
                for (int i = 0; i < clip.getItemCount(); i++) results[i] = clip.getItemAt(i).getUri();
            } else if (data != null && data.getData() != null) {
                results = new Uri[]{data.getData()};
            } else if (cameraUri != null) {
                results = new Uri[]{cameraUri};   // photo taken with the camera
            }
        }
        filePathCallback.onReceiveValue(results);
        filePathCallback = null;
    }

    private void showOffline() {
        String html = "<html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head>"
                + "<body style='margin:0;font-family:sans-serif;background:" + BG + ";color:#0F1F1C;display:flex;align-items:center;justify-content:center;height:100vh;text-align:center'>"
                + "<div style='padding:24px'><h2 style='margin:0 0 8px'>You're offline</h2>"
                + "<p style='color:#5E6E6A;margin:0 0 20px'>Check your internet connection and try again.</p>"
                + "<a href='" + appUrl + "' style='background:#0B6E5C;color:#fff;padding:12px 24px;border-radius:12px;text-decoration:none;font-weight:600'>Try again</a></div></body></html>";
        webView.loadDataWithBaseURL(appUrl, html, "text/html", "utf-8", null);
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        if (webView != null) webView.saveState(outState);
    }
}
