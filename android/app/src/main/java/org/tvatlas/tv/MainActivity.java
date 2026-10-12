package org.tvatlas.tv;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.Toast;

/**
 * MainActivity - Google TV & Android TV Leanback Container for TV Atlas
 * Provides hardware-accelerated HLS live video playback, TV remote D-Pad navigation,
 * and seamless couch leanback viewing.
 */
public class MainActivity extends Activity {

    private WebView webView;
    private FrameLayout customViewContainer;
    private WebChromeClient.CustomViewCallback customViewCallback;
    private View customView;
    private long lastBackPressTime = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Keep TV screen awake during live television broadcasts
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        setContentView(R.layout.activity_main);
        webView = findViewById(R.id.tv_webview);

        initWebView();
    }

    private void initWebView() {
        webView.setBackgroundColor(Color.parseColor("#070A0E"));
        webView.setFocusable(true);
        webView.setFocusableInTouchMode(true);
        webView.requestFocus();

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setAllowFileAccessFromFileURLs(true);
        settings.setAllowUniversalAccessFromFileURLs(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setLoadsImagesAutomatically(true);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);
        settings.setUserAgentString("Mozilla/5.0 (SmartHub; SMART-TV; Linux/SmartTV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 TVAtlas-GoogleTV/1.2");

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return false; // Load inside WebView
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onShowCustomView(View view, CustomViewCallback callback) {
                // TV Fullscreen video handling
                if (customView != null) {
                    callback.onCustomViewHidden();
                    return;
                }
                customView = view;
                customViewCallback = callback;
                FrameLayout decor = (FrameLayout) getWindow().getDecorView();
                decor.addView(view, new FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT));
                webView.setVisibility(View.GONE);
            }

            @Override
            public void onHideCustomView() {
                if (customView == null) return;
                FrameLayout decor = (FrameLayout) getWindow().getDecorView();
                decor.removeView(customView);
                customView = null;
                if (customViewCallback != null) {
                    customViewCallback.onCustomViewHidden();
                    customViewCallback = null;
                }
                webView.setVisibility(View.VISIBLE);
                webView.requestFocus();
            }
        });

        // Add JS interface for software keyboard if available
        webView.addJavascriptInterface(new WebAppInterface(), "AndroidBridge");

        // Load standalone TV Leanback interface
        webView.loadUrl("file:///android_asset/web_tv/index.html");
    }

    public class WebAppInterface {
        @android.webkit.JavascriptInterface
        public void showKeyboard() {
            runOnUiThread(() -> {
                android.view.inputmethod.InputMethodManager imm =
                    (android.view.inputmethod.InputMethodManager) getSystemService(INPUT_METHOD_SERVICE);
                if (imm != null) {
                    imm.showSoftInput(webView, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT);
                }
            });
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        // Handle Google TV Remote Back Button
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (customView != null) {
                // Exit fullscreen video
                if (webView.getWebChromeClient() != null) {
                    ((WebChromeClient) webView.getWebChromeClient()).onHideCustomView();
                    return true;
                }
            }

            // Check if Web TV UI consumed the back event (e.g. closed search modal, help modal, or cinema)
            webView.evaluateJavascript(
                "(function() { return (window.handleRemoteBack ? window.handleRemoteBack() : false); })()",
                value -> {
                    if ("false".equals(value) || "null".equals(value)) {
                        long currentTime = System.currentTimeMillis();
                        if (currentTime - lastBackPressTime < 2500) {
                            finish();
                        } else {
                            lastBackPressTime = currentTime;
                            Toast.makeText(MainActivity.this, "Press BACK again to exit TV Atlas", Toast.LENGTH_SHORT).show();
                        }
                    }
                }
            );
            return true;
        }

        // Pass D-Pad directional navigation and media keys to WebView
        return super.onKeyDown(keyCode, event);
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (webView != null) {
            webView.onPause();
            webView.pauseTimers();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (webView != null) {
            webView.onResume();
            webView.resumeTimers();
        }
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.destroy();
        }
        super.onDestroy();
    }
}
