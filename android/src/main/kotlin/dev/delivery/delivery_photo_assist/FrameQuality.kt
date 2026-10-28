package dev.delivery.delivery_photo_assist

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.RectF
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayInputStream
import kotlin.math.abs

object FrameQuality {
    fun normalizeImported(bytes: ByteArray): ByteArray? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        val options = BitmapFactory.Options().apply {
            inSampleSize = 1
            while (maxOf(bounds.outWidth, bounds.outHeight)/inSampleSize > 4096) inSampleSize *= 2
        }
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) ?: return null
        val exif = ExifInterface(ByteArrayInputStream(bytes))
        val matrix = Matrix().apply { postRotate(exif.rotationDegrees.toFloat()); if (exif.isFlipped) postScale(-1f, 1f) }
        val image = if (exif.rotationDegrees == 0 && !exif.isFlipped) decoded else Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
        return try { java.io.ByteArrayOutputStream().use { out -> image.compress(Bitmap.CompressFormat.JPEG, 95, out); out.toByteArray() } }
        finally { if (image !== decoded) image.recycle(); decoded.recycle() }
    }
    val parcelLabels=setOf("Box","Plastic bag","Handbag","Luggage and bags","cardboard box","plastic bag","shopping bag","paper bag","delivery package","insulated delivery bag")
    fun bitmap(bitmap:Bitmap,packageRect:RectF?):Map<String,Any>{
        val started=System.nanoTime();val w=bitmap.width;val h=bitmap.height
        val pixels=IntArray(w*h);bitmap.getPixels(pixels,0,w,0,0,w,h)
        fun pixel(x:Int,y:Int):Double {val p=pixels[y*w+x];return (77*((p shr 16)and 255)+150*((p shr 8)and 255)+29*(p and 255))/256.0}
        val result=mutableMapOf<String,Any>("global" to FrameQualityCore.sample(w,h,0.0,0.0,w.toDouble(),h.toDouble(),::pixel))
        packageRect?.let{n ->
            val value=FrameQualityCore.sample(w,h,n.left*w.toDouble(),n.top*h.toDouble(),n.right*w.toDouble(),n.bottom*h.toDouble(),::pixel)
            if(value.isNotEmpty())result["package"]=value
        }
        result["processingMs"]=(System.nanoTime()-started)/1e6
        result["sourceWidth"]=w;result["sourceHeight"]=h
        return result
    }
    fun preview(bitmap:Bitmap,rotation:Int,mirror:Boolean,packageRect:RectF?):Map<String,Any>{
        val matrix=Matrix().apply{postRotate(rotation.toFloat());if(mirror)postScale(-1f,1f)}
        val oriented=if(rotation==0 && !mirror)bitmap else Bitmap.createBitmap(bitmap,0,0,bitmap.width,bitmap.height,matrix,true)
        return try{FrameQuality.bitmap(oriented,packageRect)}finally{if(oriented!==bitmap)oriented.recycle()}
    }
    fun jpeg(bytes:ByteArray,packageRect:RectF?,previewAspect:Double?):Map<String,Any>{
        val start=System.nanoTime()
        val bounds=BitmapFactory.Options().apply{inJustDecodeBounds=true}
        BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds)
        val options=BitmapFactory.Options().apply{inSampleSize=1;while(bounds.outWidth/inSampleSize>960 || bounds.outHeight/inSampleSize>960)inSampleSize*=2}
        val decoded=BitmapFactory.decodeByteArray(bytes,0,bytes.size,options)?:return emptyMap()
        val exif=ExifInterface(ByteArrayInputStream(bytes))
        val rotation=exif.rotationDegrees
        val matrix=Matrix().apply{postRotate(rotation.toFloat());if(exif.isFlipped)postScale(-1f,1f)}
        val image=if(rotation==0 && !exif.isFlipped)decoded else Bitmap.createBitmap(decoded,0,0,decoded.width,decoded.height,matrix,true)
        return try{
            val same=previewAspect==null || abs(previewAspect-image.width.toDouble()/image.height)<.03
            bitmap(image,if(same)packageRect else null).toMutableMap().apply{
                put("photoWidth",if(rotation%180!=0)bounds.outHeight else bounds.outWidth);put("photoHeight",if(rotation%180!=0)bounds.outWidth else bounds.outHeight)
                put("processingMs",(System.nanoTime()-start)/1e6)
                put("scope","saved_jpeg; package ROI from latest preview, not re-detection")
                if(!same)put("packageCheck","unavailable_aspect_mismatch")
            }
        }finally{if(image!==decoded)image.recycle();decoded.recycle()}
    }
}
