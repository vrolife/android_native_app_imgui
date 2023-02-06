package org.napp;

import android.app.Service;
import android.content.Intent;
import android.content.res.AssetManager;
import android.os.IBinder;
import android.widget.Button;
import android.view.Gravity;
import android.view.WindowManager;
import android.view.WindowManager.LayoutParams;
import android.graphics.PixelFormat;
import android.view.Surface;
import android.view.SurfaceView;
import android.view.SurfaceHolder;
import android.hardware.input.InputManager;

public class NativeService extends Service implements SurfaceHolder.Callback {
    static {
        System.loadLibrary("napp");
    }
    
    private native long native_on_create(
        AssetManager asset_mamager,
        String internal_data_path, 
        String external_data_path, 
        String obb_path, 
        int sdk_version);

    private native void native_on_destroy(long ptr);
    private native void native_on_low_memory(long ptr);
    private native void native_surface_created(long ptr, Surface surface);
    private native void native_surface_changed(long ptr, Surface surface, int format, int width, int height);
    private native void native_surface_destroyed(long ptr, Surface surface);

    private long ptr;
    private boolean destrpyed;

    @Override
    public IBinder onBind (Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {

        final LayoutParams params = new WindowManager.LayoutParams(
            LayoutParams.WRAP_CONTENT,
            LayoutParams.WRAP_CONTENT,
            LayoutParams.TYPE_PHONE,
            LayoutParams.FLAG_NOT_FOCUSABLE | LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSLUCENT);
        
        params.gravity = Gravity.TOP | Gravity.LEFT;
        params.width = 500;
        params.height = 500;
        params.x=0;
        params.y=0;
        params.alpha = 0.5f;
        
        SurfaceView view = new SurfaceView(this);
        SurfaceHolder holder = view.getHolder();
        holder.addCallback(this);

        WindowManager window_manager = (WindowManager)getSystemService(WINDOW_SERVICE);
        window_manager.addView(view, params);

        ptr = native_on_create(
            getAssets(),
            getApplicationContext().getFilesDir().getAbsolutePath(),
            getApplicationContext().getExternalFilesDir(null).getAbsolutePath(),
            getApplicationContext().getObbDir().getAbsolutePath(),
            android.os.Build.VERSION.SDK_INT
        );

        super.onCreate();
    }

    @Override
    public void onDestroy() {
        destrpyed = true;
        native_on_destroy(ptr);
        ptr = 0;
        super.onDestroy();
    }

    @Override
    public void onLowMemory () {
        native_on_low_memory(ptr);
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        if (!destrpyed) {
            native_surface_created(ptr, holder.getSurface());
        }
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        if (!destrpyed) {
            native_surface_changed(ptr, holder.getSurface(), format, width, height);
        }
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        if (!destrpyed) {
            native_surface_destroyed(ptr, holder.getSurface());
        }
    }
}
