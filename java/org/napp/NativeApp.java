package org.napp;

import android.app.Application;
import android.content.Context;
import android.content.res.Configuration;

public class NativeApp extends Application {

    static {
        System.loadLibrary("napp");
    }

    private native void native_attach_base_context(Context base);
    private native void native_on_create();

    @Override
    protected void attachBaseContext (Context base) {
        native_attach_base_context(base);
        super.attachBaseContext(base);
    }
    
    @Override
    public void onCreate() {
        native_on_create();
    }
}
