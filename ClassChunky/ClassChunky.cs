// ############################################### 
// # Custom LockBits class for pixel get/set     #
// # ClassChunky.dll                             #
// #                                             #
// # Currently implemented :                     #
// # - Lock (reserve bitmap memory)              #
// # - Release (unlock memory)                   #
// # - SetPixel                                  #
// # - GetPixel                                  #
// # - SetChunk (set pixel on block)             #
// #                                             #
// # can be compiled via script in .\ClassChunky #
// #                                             #
// # (c) 2017 - current by deep4                 #
// ###############################################

using System;
using System.Drawing;
using System.Drawing.Imaging;

unsafe public class Chunky
{
    private struct Pix
    {
        public byte b;
        public byte g;
        public byte r;
        public byte a;
    }

    private Pix* pixelData = null;
    private Bitmap work = null;
    private int width = 0;
    private BitmapData bData = null;
    private Byte* Origin = null;
	private Pix* chunk = null;

    public Chunky(Bitmap inputBitmap)
    {
        work = inputBitmap;
    }

    // Reserve memory, get width of image etc.
	public void Lock()
    {
		Rectangle bounds = new Rectangle(Point.Empty, work.Size);
       	width = (int)(bounds.Width * sizeof(Pix));
       	if (width % 4 != 0) width = (((width >> 2) + 1) << 2);
       	bData = work.LockBits(bounds, ImageLockMode.ReadWrite, PixelFormat.Format32bppPArgb);
       	Origin = (Byte*)bData.Scan0.ToPointer();
		chunk = (Pix*)(Origin);
    }

    // Return color of given pixel in ARGB (32bpp)
	public Color GetPixel(int x, int y)
    {
		pixelData = (Pix*)(Origin + y * width + x * sizeof(Pix));
       	return Color.FromArgb(pixelData->a, pixelData->r, pixelData->g, pixelData->b);
    }

    // Set color of given pixel in ARGB (32bpp)
	public void SetPixel(int x, int y, Color color)
    {
		Pix* data = (Pix*)(Origin + y * width + x * sizeof(Pix));
       	data->a = color.A;
       	data->r = color.R;
       	data->g = color.G;
       	data->b = color.B;
	}

	// Continiuous pixel-writing of WHOLE locked image from beginning to end
	// No need to set mempointer, just call this function in a loop with a color
	public void SetChunk(Color color)
    {
		chunk->a = color.A;
   		chunk->r = color.R;
   		chunk->g = color.G;
   		chunk->b = color.B;
		chunk++;
	}

    // unlocks the image so that it can be copied etc.
	public void Release()
    {
		work.UnlockBits(bData);
       	bData = null;
   	    Origin = null;
    }
}
