using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Runtime.InteropServices;

// Small image toolkit used by optimize-images.ps1 (Windows PowerShell 5.1 / .NET Framework).
public static class LcbImaging
{
    static ImageCodecInfo JpegCodec()
    {
        foreach (ImageCodecInfo c in ImageCodecInfo.GetImageEncoders())
            if (c.MimeType == "image/jpeg") return c;
        throw new Exception("JPEG encoder not found");
    }

    static void SaveJpeg(Bitmap bmp, string dst, long quality)
    {
        EncoderParameters p = new EncoderParameters(1);
        p.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality);
        bmp.Save(dst, JpegCodec(), p);
    }

    static Graphics HQ(Bitmap bmp)
    {
        Graphics g = Graphics.FromImage(bmp);
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.CompositingQuality = CompositingQuality.HighQuality;
        return g;
    }

    // Resize to a target width, keeping aspect ratio. Returns "width x height".
    public static string Resize(string src, string dst, int width, long quality)
    {
        using (Image img = Image.FromFile(src))
        {
            int w = Math.Min(width, img.Width);
            int h = (int)Math.Round(img.Height * (w / (double)img.Width));
            using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb))
            using (Graphics g = HQ(bmp))
            using (ImageAttributes ia = new ImageAttributes())
            {
                ia.SetWrapMode(WrapMode.TileFlipXY);
                g.DrawImage(img, new Rectangle(0, 0, w, h), 0, 0, img.Width, img.Height, GraphicsUnit.Pixel, ia);
                SaveJpeg(bmp, dst, quality);
            }
            return w + "x" + h;
        }
    }

    // Cover-crop to an exact size around a focal point (fx, fy in 0..1).
    public static void Cover(string src, string dst, int w, int h, double fx, double fy, long quality)
    {
        using (Image img = Image.FromFile(src))
        {
            double scale = Math.Max(w / (double)img.Width, h / (double)img.Height);
            double cw = w / scale, ch = h / scale;
            double cx = Math.Max(0, Math.Min(img.Width - cw, img.Width * fx - cw / 2));
            double cy = Math.Max(0, Math.Min(img.Height - ch, img.Height * fy - ch / 2));
            using (Bitmap bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb))
            using (Graphics g = HQ(bmp))
            {
                g.DrawImage(img, new Rectangle(0, 0, w, h), new RectangleF((float)cx, (float)cy, (float)cw, (float)ch), GraphicsUnit.Pixel);
                SaveJpeg(bmp, dst, quality);
            }
        }
    }

    // Turns a flat-background wordmark into a transparent PNG in a chosen colour,
    // trimmed to its ink and scaled to targetWidth. Returns the sampled ink colour as hex.
    public static string Wordmark(string src, string dst, int r, int g, int b, int targetWidth, bool keepInk)
    {
        using (Bitmap source = new Bitmap(src))
        {
            int W = source.Width, H = source.Height;
            Bitmap s = source.Clone(new Rectangle(0, 0, W, H), PixelFormat.Format32bppArgb);
            BitmapData sd = s.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] px = new byte[sd.Stride * H];
            Marshal.Copy(sd.Scan0, px, 0, px.Length);
            int stride = sd.Stride;
            s.UnlockBits(sd);
            s.Dispose();

            // Background: average of the four corner patches.
            double bgL = 0; int n = 0;
            int[] cxs = { 5, W - 25 }; int[] cys = { 5, H - 25 };
            foreach (int ox in cxs) foreach (int oy in cys)
                for (int y = oy; y < oy + 20; y++) for (int x = ox; x < ox + 20; x++)
                { int i = y * stride + x * 4; bgL += Lum(px[i + 2], px[i + 1], px[i]); n++; }
            bgL /= n;

            // Ink: average of the darkest pixels.
            double minL = 255;
            for (int i = 0; i < px.Length; i += 4) minL = Math.Min(minL, Lum(px[i + 2], px[i + 1], px[i]));
            double ir = 0, ig = 0, ib = 0, inkL = 0; int m = 0;
            for (int i = 0; i < px.Length; i += 4)
            {
                double L = Lum(px[i + 2], px[i + 1], px[i]);
                if (L < minL + 25) { ir += px[i + 2]; ig += px[i + 1]; ib += px[i]; inkL += L; m++; }
            }
            ir /= m; ig /= m; ib /= m; inkL /= m;
            if (keepInk) { r = (int)ir; g = (int)ig; b = (int)ib; }

            byte[] outPx = new byte[W * H * 4];
            int minX = W, minY = H, maxX = 0, maxY = 0;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * stride + x * 4;
                    double L = Lum(px[i + 2], px[i + 1], px[i]);
                    double a = (bgL - L) / (bgL - inkL);
                    a = a < 0.04 ? 0 : (a > 0.96 ? 1 : a);
                    int o = (y * W + x) * 4;
                    outPx[o] = (byte)b; outPx[o + 1] = (byte)g; outPx[o + 2] = (byte)r; outPx[o + 3] = (byte)(a * 255);
                    if (a > 0.1) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
                }

            using (Bitmap full = new Bitmap(W, H, PixelFormat.Format32bppArgb))
            {
                BitmapData fd = full.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                Marshal.Copy(outPx, 0, fd.Scan0, outPx.Length);
                full.UnlockBits(fd);

                int pad = 6;
                Rectangle crop = Rectangle.FromLTRB(Math.Max(0, minX - pad), Math.Max(0, minY - pad), Math.Min(W, maxX + pad), Math.Min(H, maxY + pad));
                int tw = Math.Min(targetWidth, crop.Width);
                int th = (int)Math.Round(crop.Height * (tw / (double)crop.Width));
                using (Bitmap outBmp = new Bitmap(tw, th, PixelFormat.Format32bppArgb))
                using (Graphics gr = HQ(outBmp))
                {
                    gr.Clear(Color.Transparent);
                    gr.DrawImage(full, new Rectangle(0, 0, tw, th), crop, GraphicsUnit.Pixel);
                    outBmp.Save(dst, ImageFormat.Png);
                }
            }
            return String.Format("#{0:X2}{1:X2}{2:X2}", (int)ir, (int)ig, (int)ib);
        }
    }

    // Square "LCB" monogram icon: ivory serif letters on deep forest.
    public static void Monogram(string dst, int size, string fontName)
    {
        using (Bitmap bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb))
        using (Graphics g = HQ(bmp))
        {
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.Clear(ColorTranslator.FromHtml("#28372F"));
            using (Font f = new Font(fontName, size * 0.36f, FontStyle.Regular, GraphicsUnit.Pixel))
            using (SolidBrush br = new SolidBrush(ColorTranslator.FromHtml("#F4F0E7")))
            using (StringFormat sf = new StringFormat())
            {
                sf.Alignment = StringAlignment.Center;
                sf.LineAlignment = StringAlignment.Center;
                g.DrawString("LCB", f, br, new RectangleF(0, size * 0.02f, size, size), sf);
            }
            if (size >= 64)
            {
                using (Pen p = new Pen(ColorTranslator.FromHtml("#C6B9A5"), Math.Max(1f, size / 128f)))
                {
                    float inset = size * 0.1f;
                    g.DrawRectangle(p, inset, inset, size - inset * 2, size - inset * 2);
                }
            }
            bmp.Save(dst, ImageFormat.Png);
        }
    }

    static double Lum(byte r, byte g, byte b) { return 0.2126 * r + 0.7152 * g + 0.0722 * b; }
}
