package dev.delivery.delivery_photo_assist

import kotlin.math.*

object FrameQualityCore {
    fun metrics(luma:DoubleArray,width:Int,height:Int,sourceWidth:Int,sourceHeight:Int):Map<String,Any> {
        if(width<16 || height<16 || luma.size!=width*height) return emptyMap()
        var sum=0.0;var sum2=0.0;var lapSum=0.0;var lap2=0.0
        var dark=0;var clipped=0;var edges=0;var count=0
        for(y in 1 until height-1) for(x in 1 until width-1) {
            val i=y*width+x;val c=luma[i]
            val lap=luma[i-1]+luma[i+1]+luma[i-width]+luma[i+width]-4*c
            val gradient=abs(luma[i+1]-luma[i-1])+abs(luma[i+width]-luma[i-width])
            sum+=c;sum2+=c*c;lapSum+=lap;lap2+=lap*lap
            if(c<25)dark++;if(c>245)clipped++;if(gradient>12)edges++;count++
        }
        val n=count.toDouble();val mean=sum/n
        return mapOf("laplacianVariance" to max(0.0,lap2/n-(lapSum/n).pow(2)),
            "contrastStd" to sqrt(max(0.0,sum2/n-mean*mean)),"meanLuma" to mean,
            "darkFraction" to dark/n,"clippedFraction" to clipped/n,"edgeFraction" to edges/n,
            "analysisWidth" to width,"analysisHeight" to height,
            "sourceWidth" to sourceWidth,"sourceHeight" to sourceHeight)
    }

    fun sample(width:Int,height:Int,left:Double,top:Double,right:Double,bottom:Double,pixel:(Int,Int)->Double):Map<String,Any> {
        val l=left.coerceIn(0.0,width.toDouble());val t=top.coerceIn(0.0,height.toDouble())
        val r=right.coerceIn(l,width.toDouble());val b=bottom.coerceIn(t,height.toDouble())
        if(r-l<24 || b-t<24)return emptyMap()
        val scale=min(1.0,320.0/max(r-l,b-t));val w=max(16,((r-l)*scale).toInt());val h=max(16,((b-t)*scale).toInt())
        val dx=(r-l)/w;val dy=(b-t)/h;val luma=DoubleArray(w*h)
        for(y in 0 until h)for(x in 0 until w){
            val x0=(l+(x+.25)*dx).toInt().coerceIn(0,width-1);val x1=(l+(x+.75)*dx).toInt().coerceIn(0,width-1)
            val y0=(t+(y+.25)*dy).toInt().coerceIn(0,height-1);val y1=(t+(y+.75)*dy).toInt().coerceIn(0,height-1)
            luma[y*w+x]=(pixel(x0,y0)+pixel(x1,y0)+pixel(x0,y1)+pixel(x1,y1))/4
        }
        return metrics(luma,w,h,(r-l).toInt(),(b-t).toInt())
    }
}
