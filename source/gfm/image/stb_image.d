
/// D translation of stb_image-1.33 (http://nothings.org/stb_image.c)
/// Removed:
/// $(UL
///   $(LI Loading with callbacks.)
///   $(LI HDR support.)
///   $(LI STDIO support.)
/// )
/// Added:
/// $(UL
///   $(LI Exceptions.)
///  )
/// TODO:
/// $(UL
///   $(LI Support a range as input.)
///  )

module gfm.image.stb_image;

import core.stdc.stdlib;
import core.stdc.string;

enum STBI_VERSION = 1;

/// The exception type thrown when loading an image failed.
class STBImageException : Exception
{
    public
    {
        this(string msg)
        {
            super(msg);
        }
    }
}

enum : int
{
   STBI_default    = 0, // only used for req_comp
   STBI_grey       = 1,
   STBI_grey_alpha = 2,
   STBI_rgb        = 3,
   STBI_rgb_alpha  = 4
};

// define faster low-level operations (typically SIMD support)


uint stbi_lrot(uint x, uint y)
{
    return (x << y) | (x >> (32 - y));
}

// stbi structure is our basic context used by all images, so it
// contains all the IO context, plus some basic image information
struct stbi
{
   uint img_x, img_y;
   int img_n, img_out_n;
   
   int buflen;
   ubyte buffer_start[128];

   ubyte *img_buffer;
   ubyte *img_buffer_end;
   ubyte *img_buffer_original;
}


// initialize a memory-decode context
void start_mem(stbi *s, const(ubyte)*buffer, int len)
{
   s.img_buffer = s.img_buffer_original = cast(ubyte *) buffer;
   s.img_buffer_end = cast(ubyte *) buffer+len;
}

void stbi_rewind(stbi *s)
{
   // conceptually rewind SHOULD rewind to the beginning of the stream,
   // but we just rewind to the beginning of the initial buffer, because
   // we only use it after doing 'test', which only ever looks at at most 92 bytes
   s.img_buffer = s.img_buffer_original;
}


char *stbi_load_main(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   if (stbi_jpeg_test(s)) return stbi_jpeg_load(s,x,y,comp,req_comp);
   if (stbi_png_test(s))  return stbi_png_load(s,x,y,comp,req_comp);
   if (stbi_bmp_test(s))  return stbi_bmp_load(s,x,y,comp,req_comp);
   if (stbi_gif_test(s))  return stbi_gif_load(s,x,y,comp,req_comp);
   if (stbi_psd_test(s))  return stbi_psd_load(s,x,y,comp,req_comp);
   if (stbi_pic_test(s))  return stbi_pic_load(s,x,y,comp,req_comp);

   // test tga last because it's a crappy test!
   if (stbi_tga_test(s))
      return stbi_tga_load(s,x,y,comp,req_comp);

   throw new STBImageException("Image not of any known type, or corrupt");
}

/// Loads an image from memory.
ubyte* stbi_load_from_memory(ubyte[] buffer, out int width, out int height, out int components, int requestedComponents)
{
   stbi s;
   start_mem(&s, buffer.ptr, buffer.length);
   return cast(ubyte*) stbi_load_main(&s, &width, &height, &components, requestedComponents);
}

/// Frees an image loaded by stb_image.
void stbi_image_free(void *retval_from_stbi_load)
{
    free(retval_from_stbi_load);
}


//
// Common code used by all image loaders
//

enum : int
{
   SCAN_load=0,
   SCAN_type,
   SCAN_header
};


int get8(stbi *s)
{
   if (s.img_buffer < s.img_buffer_end)
      return *s.img_buffer++;
   
   return 0;
}

int at_eof(stbi *s)
{
   return s.img_buffer >= s.img_buffer_end;   
}

ubyte get8u(stbi *s)
{
   return cast(ubyte) get8(s);
}

void skip(stbi *s, int n)
{
   s.img_buffer += n;
}

int getn(stbi *s, char *buffer, int n)
{
   if (s.img_buffer+n <= s.img_buffer_end) {
      memcpy(buffer, s.img_buffer, n);
      s.img_buffer += n;
      return 1;
   } else
      return 0;
}

int get16(stbi *s)
{
   int z = get8(s);
   return (z << 8) + get8(s);
}

uint get32(stbi *s)
{
   uint z = get16(s);
   return (z << 16) + get16(s);
}

int get16le(stbi *s)
{
   int z = get8(s);
   return z + (get8(s) << 8);
}

uint get32le(stbi *s)
{
   uint z = get16le(s);
   return z + (get16le(s) << 16);
}

//
//  generic converter from built-in img_n to req_comp
//    individual types do this automatically as much as possible (e.g. jpeg
//    does all cases internally since it needs to colorspace convert anyway,
//    and it never has alpha, so very few cases ). png can automatically
//    interleave an alpha=255 channel, but falls back to this for other cases
//
//  assume data buffer is malloced, so malloc a new one and free that one
//  only failure mode is malloc failing

ubyte compute_y(int r, int g, int b)
{
   return cast(ubyte) (((r*77) + (g*150) +  (29*b)) >> 8);
}

ubyte *convert_format(ubyte *data, int img_n, int req_comp, uint x, uint y)
{
    int i,j;
    ubyte *good;

    if (req_comp == img_n) return data;
    assert(req_comp >= 1 && req_comp <= 4);

    good = cast(ubyte *) malloc(req_comp * x * y);
    if (good == null) {
        free(data);
        throw new STBImageException("Out of memory");
    }

    for (j=0; j < cast(int) y; ++j) {
        ubyte *src  = data + j * x * img_n   ;
        ubyte *dest = good + j * x * req_comp;

        // convert source image with img_n components to one with req_comp components;
        // avoid switch per pixel, so use switch per scanline and massive macros
        switch (img_n * 8 + req_comp) 
        {
            case 1 * 8 + 2: 
                for(i=x-1; i >= 0; --i, src += 1, dest += 2)
                    dest[0] = src[0], dest[1] = 255;
                break;
            case 1 * 8 + 3: 
                for(i=x-1; i >= 0; --i, src += 1, dest += 3)
                    dest[0]=dest[1]=dest[2]=src[0]; 
                break;
            case 1 * 8 + 4: 
                for(i=x-1; i >= 0; --i, src += 1, dest += 4)
                    dest[0]=dest[1]=dest[2]=src[0], dest[3]=255; 
                break;
            case 2 * 8 + 1: 
                for(i=x-1; i >= 0; --i, src += 2, dest += 1)
                    dest[0]=src[0]; 
                break;
            case 2 * 8 + 3: 
                for(i=x-1; i >= 0; --i, src += 2, dest += 3)
                    dest[0]=dest[1]=dest[2]=src[0]; 
                break;
            case 2 * 8 + 4: 
                for(i=x-1; i >= 0; --i, src += 2, dest += 4)
                    dest[0]=dest[1]=dest[2]=src[0], dest[3]=src[1]; 
                break;
            case 3 * 8 + 4:
                for(i=x-1; i >= 0; --i, src += 3, dest += 4) 
                    dest[0]=src[0],dest[1]=src[1],dest[2]=src[2],dest[3]=255; 
                break;
            case 3 * 8 + 1: 
                for(i=x-1; i >= 0; --i, src += 3, dest += 1)
                    dest[0]=compute_y(src[0],src[1],src[2]); 
                break;
            case 3 * 8 + 2: 
                for(i=x-1; i >= 0; --i, src += 3, dest += 2)
                    dest[0]=compute_y(src[0],src[1],src[2]), dest[1] = 255; 
                break;
            case 4 * 8 + 1:
                for(i=x-1; i >= 0; --i, src += 4, dest += 1)
                    dest[0]=compute_y(src[0],src[1],src[2]); 
                break;
            case 4 * 8 + 2: 
                for(i=x-1; i >= 0; --i, src += 4, dest += 2)
                    dest[0]=compute_y(src[0],src[1],src[2]), dest[1] = src[3]; 
                break;
            case 4 * 8 + 3: 
                for(i=x-1; i >= 0; --i, src += 4, dest += 3)
                    dest[0]=src[0],dest[1]=src[1],dest[2]=src[2]; 
                break;
            default: assert(0);
        }
    }

    free(data);
    return good;
}

//
//  "baseline" JPEG/JFIF decoder (not actually fully baseline implementation)
//
//    simple implementation
//      - channel subsampling of at most 2 in each dimension
//      - doesn't support delayed output of y-dimension
//      - simple interface (only one output format: 8-bit interleaved RGB)
//      - doesn't try to recover corrupt jpegs
//      - doesn't allow partial loading, loading multiple at once
//      - still fast on x86 (copying globals into locals doesn't help x86)
//      - allocates lots of intermediate memory (full size of all components)
//        - non-interleaved case requires this anyway
//        - allows good upsampling (see next)
//    high-quality
//      - upsampled channels are bilinearly interpolated, even across blocks
//      - quality integer IDCT derived from IJG's 'slow'
//    performance
//      - fast huffman; reasonable integer IDCT
//      - uses a lot of intermediate memory, could cache poorly
//      - load http://nothings.org/remote/anemones.jpg 3 times on 2.8Ghz P4
//          stb_jpeg:   1.34 seconds (MSVC6, default release build)
//          stb_jpeg:   1.06 seconds (MSVC6, processor = Pentium Pro)
//          IJL11.dll:  1.08 seconds (compiled by intel)
//          IJG 1998:   0.98 seconds (MSVC6, makefile provided by IJG)
//          IJG 1998:   0.95 seconds (MSVC6, makefile + proc=PPro)

// huffman decoding acceleration
enum FAST_BITS = 9;  // larger handles more cases; smaller stomps less cache

struct huffman
{
   ubyte[1 << FAST_BITS] fast;
   // weirdly, repacking this into AoS is a 10% speed loss, instead of a win
   ushort[256] code;
   ubyte[256] values;
   ubyte[257] size;
   uint[18] maxcode;
   int[17] delta;   // old 'firstsymbol' - old 'firstcode'
}

struct jpeg
{
   stbi *s;
   huffman[4] huff_dc;
   huffman[4] huff_ac;
   ubyte[64][4] dequant;

// sizes for components, interleaved MCUs
   int img_h_max, img_v_max;
   int img_mcu_x, img_mcu_y;
   int img_mcu_w, img_mcu_h;

// definition of jpeg image component
   struct img_comp_
   {
      int id;
      int h,v;
      int tq;
      int hd,ha;
      int dc_pred;

      int x,y,w2,h2;
      ubyte *data;
      void *raw_data;
      ubyte *linebuf;
   } 
   
   img_comp_[4] img_comp;

   uint         code_buffer; // jpeg entropy-coded buffer
   int            code_bits;   // number of valid bits
   char           marker;      // marker seen while filling entropy buffer
   int            nomore;      // flag if we saw a marker so must stop

   int scan_n;
   int[4] order;
   int restart_interval, todo;
}


int build_huffman(huffman *h, int *count)
{
   int i,j,k=0,code;
   // build size list for each symbol (from JPEG spec)
   for (i=0; i < 16; ++i)
      for (j=0; j < count[i]; ++j)
         h.size[k++] = cast(ubyte) (i+1);
   h.size[k] = 0;

   // compute actual symbols (from jpeg spec)
   code = 0;
   k = 0;
   for(j=1; j <= 16; ++j) {
      // compute delta to add to code to compute symbol id
      h.delta[j] = k - code;
      if (h.size[k] == j) {
         while (h.size[k] == j)
            h.code[k++] = cast(ushort) (code++);
         if (code-1 >= (1 << j)) 
             throw new STBImageException("Bad code lengths, corrupt JPEG");
      }
      // compute largest code + 1 for this size, preshifted as needed later
      h.maxcode[j] = code << (16-j);
      code <<= 1;
   }
   h.maxcode[j] = 0xffffffff;

   // build non-spec acceleration table; 255 is flag for not-accelerated
   memset(h.fast.ptr, 255, 1 << FAST_BITS);
   for (i=0; i < k; ++i) {
      int s = h.size[i];
      if (s <= FAST_BITS) {
         int c = h.code[i] << (FAST_BITS-s);
         int m = 1 << (FAST_BITS-s);
         for (j=0; j < m; ++j) {
            h.fast[c+j] = cast(ubyte) i;
         }
      }
   }
   return 1;
}

void grow_buffer_unsafe(jpeg *j)
{
   do {
      int b = j.nomore ? 0 : get8(j.s);
      if (b == 0xff) {
         int c = get8(j.s);
         if (c != 0) {
            j.marker = cast(char) c;
            j.nomore = 1;
            return;
         }
      }
      j.code_buffer |= b << (24 - j.code_bits);
      j.code_bits += 8;
   } while (j.code_bits <= 24);
}

// (1 << n) - 1
static immutable uint bmask[17]=[0,1,3,7,15,31,63,127,255,511,1023,2047,4095,8191,16383,32767,65535];

// decode a jpeg huffman value from the bitstream
int decode(jpeg *j, huffman *h)
{
   uint temp;
   int c,k;

   if (j.code_bits < 16) grow_buffer_unsafe(j);

   // look at the top FAST_BITS and determine what symbol ID it is,
   // if the code is <= FAST_BITS
   c = (j.code_buffer >> (32 - FAST_BITS)) & ((1 << FAST_BITS)-1);
   k = h.fast[c];
   if (k < 255) {
      int s = h.size[k];
      if (s > j.code_bits)
         return -1;
      j.code_buffer <<= s;
      j.code_bits -= s;
      return h.values[k];
   }

   // naive test is to shift the code_buffer down so k bits are
   // valid, then test against maxcode. To speed this up, we've
   // preshifted maxcode left so that it has (16-k) 0s at the
   // end; in other words, regardless of the number of bits, it
   // wants to be compared against something shifted to have 16;
   // that way we don't need to shift inside the loop.
   temp = j.code_buffer >> 16;
   for (k=FAST_BITS+1 ; ; ++k)
      if (temp < h.maxcode[k])
         break;
   if (k == 17) {
      // error! code not found
      j.code_bits -= 16;
      return -1;
   }

   if (k > j.code_bits)
      return -1;

   // convert the huffman code to the symbol id
   c = ((j.code_buffer >> (32 - k)) & bmask[k]) + h.delta[k];
   assert((((j.code_buffer) >> (32 - h.size[c])) & bmask[h.size[c]]) == h.code[c]);

   // convert the id to a symbol
   j.code_bits -= k;
   j.code_buffer <<= k;
   return h.values[c];
}

// combined JPEG 'receive' and JPEG 'extend', since baseline
// always extends everything it receives.
int extend_receive(jpeg *j, int n)
{
   uint m = 1 << (n-1);
   uint k;
   if (j.code_bits < n) grow_buffer_unsafe(j);

   k = stbi_lrot(j.code_buffer, n);
   j.code_buffer = k & ~bmask[n];
   k &= bmask[n];
   j.code_bits -= n;

   // the following test is probably a random branch that won't
   // predict well. I tried to table accelerate it but failed.
   // maybe it's compiling as a conditional move?
   if (k < m)
      return (-1 << n) + k + 1;
   else
      return k;
}

// given a value that's at position X in the zigzag stream,
// where does it appear in the 8x8 matrix coded as row-major?
static immutable ubyte dezigzag[64+15] =
[
    0,  1,  8, 16,  9,  2,  3, 10,
   17, 24, 32, 25, 18, 11,  4,  5,
   12, 19, 26, 33, 40, 48, 41, 34,
   27, 20, 13,  6,  7, 14, 21, 28,
   35, 42, 49, 56, 57, 50, 43, 36,
   29, 22, 15, 23, 30, 37, 44, 51,
   58, 59, 52, 45, 38, 31, 39, 46,
   53, 60, 61, 54, 47, 55, 62, 63,
   // let corrupt input sample past end
   63, 63, 63, 63, 63, 63, 63, 63,
   63, 63, 63, 63, 63, 63, 63
];

// decode one 64-entry block--
int decode_block(jpeg *j, short data[64], huffman *hdc, huffman *hac, int b)
{
   int diff,dc,k;
   int t = decode(j, hdc);
   if (t < 0)
       throw new STBImageException("Bad huffman code, corrupt JPEG");

   // 0 all the ac values now so we can do it 32-bits at a time
   memset(data.ptr,0,64*(data[0]).sizeof);

   diff = t ? extend_receive(j, t) : 0;
   dc = j.img_comp[b].dc_pred + diff;
   j.img_comp[b].dc_pred = dc;
   data[0] = cast(short) dc;

   // decode AC components, see JPEG spec
   k = 1;
   do {
      int r,s;
      int rs = decode(j, hac);
      if (rs < 0)
         throw new STBImageException("Bad huffman code, corrupt JPEG");
      s = rs & 15;
      r = rs >> 4;
      if (s == 0) {
         if (rs != 0xf0) break; // end block
         k += 16;
      } else {
         k += r;
         // decode into unzigzag'd location
         data[dezigzag[k++]] = cast(short) extend_receive(j,s);
      }
   } while (k < 64);
   return 1;
}

// take a -128..127 value and clamp it and convert to 0..255
ubyte clamp(int x)
{
   // trick to use a single test to catch both cases
   if (cast(uint) x > 255) {
      if (x < 0) return 0;
      if (x > 255) return 255;
   }
   return cast(ubyte) x;
}

int f2f(double x)
{
    return cast(int)(x * 4096 + 0.5);
}

int fsh(int x)
{
    return x << 12;
}

// derived from jidctint -- DCT_ISLOW
void IDCT_1D(int s0, int s1, int s2, int s3, int s4, int s5, int s6, int s7,
             out int t0, out int t1, out int t2, out int t3,
             out int x0, out int x1, out int x2, out int x3)
{
   int p1,p2,p3,p4,p5; 
   p2 = s2;                                    
   p3 = s6;                                    
   p1 = (p2+p3) * f2f(0.5411961f);             
   t2 = p1 + p3*f2f(-1.847759065f);            
   t3 = p1 + p2*f2f( 0.765366865f);            
   p2 = s0;                                    
   p3 = s4;                                    
   t0 = fsh(p2+p3);                            
   t1 = fsh(p2-p3);                            
   x0 = t0+t3;                                 
   x3 = t0-t3;                                 
   x1 = t1+t2;                                 
   x2 = t1-t2;                                 
   t0 = s7;                                    
   t1 = s5;                                    
   t2 = s3;                                    
   t3 = s1;                                    
   p3 = t0+t2;                                 
   p4 = t1+t3;                                 
   p1 = t0+t3;                                 
   p2 = t1+t2;                                 
   p5 = (p3+p4)*f2f( 1.175875602f);            
   t0 = t0*f2f( 0.298631336f);                 
   t1 = t1*f2f( 2.053119869f);                 
   t2 = t2*f2f( 3.072711026f);                 
   t3 = t3*f2f( 1.501321110f);                 
   p1 = p5 + p1*f2f(-0.899976223f);            
   p2 = p5 + p2*f2f(-2.562915447f);            
   p3 = p3*f2f(-1.961570560f);                 
   p4 = p4*f2f(-0.390180644f);                 
   t3 += p1+p4;                                
   t2 += p2+p3;                                
   t1 += p2+p4;                                
   t0 += p1+p3;
 }

alias stbi_dequantize_t = ubyte;

// .344 seconds on 3*anemones.jpg
void idct_block(ubyte *out_, int out_stride, short data[64], stbi_dequantize_t *dequantize)
{
   int i;
   int[64] val;
   int*v = val.ptr;
   stbi_dequantize_t *dq = dequantize;
   ubyte *o;
   short *d = data.ptr;

   // columns
   for (i=0; i < 8; ++i,++d,++dq, ++v) {
      // if all zeroes, shortcut -- this avoids dequantizing 0s and IDCTing
      if (d[ 8]==0 && d[16]==0 && d[24]==0 && d[32]==0
           && d[40]==0 && d[48]==0 && d[56]==0) {
         //    no shortcut                 0     seconds
         //    (1|2|3|4|5|6|7)==0          0     seconds
         //    all separate               -0.047 seconds
         //    1 && 2|3 && 4|5 && 6|7:    -0.047 seconds
         int dcterm = d[0] * dq[0] << 2;
         v[0] = v[8] = v[16] = v[24] = v[32] = v[40] = v[48] = v[56] = dcterm;
      } else {
         int t0, t1, t2, t3, x0, x1, x2, x3;
         IDCT_1D(d[ 0]*dq[ 0],d[ 8]*dq[ 8],d[16]*dq[16],d[24]*dq[24],
                 d[32]*dq[32],d[40]*dq[40],d[48]*dq[48],d[56]*dq[56],
                 t0, t1, t2, t3, x0, x1, x2, x3);
         // constants scaled things up by 1<<12; let's bring them back
         // down, but keep 2 extra bits of precision
         x0 += 512; x1 += 512; x2 += 512; x3 += 512;
         v[ 0] = (x0+t3) >> 10;
         v[56] = (x0-t3) >> 10;
         v[ 8] = (x1+t2) >> 10;
         v[48] = (x1-t2) >> 10;
         v[16] = (x2+t1) >> 10;
         v[40] = (x2-t1) >> 10;
         v[24] = (x3+t0) >> 10;
         v[32] = (x3-t0) >> 10;
      }
   }

   for (i=0, v=val.ptr, o=out_; i < 8; ++i,v+=8,o+=out_stride) {

      // no fast case since the first 1D IDCT spread components out
      int t0, t1, t2, t3, x0, x1, x2, x3;
      IDCT_1D(v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7], t0, t1, t2, t3, x0, x1, x2, x3);
      // constants scaled things up by 1<<12, plus we had 1<<2 from first
      // loop, plus horizontal and vertical each scale by sqrt(8) so together
      // we've got an extra 1<<3, so 1<<17 total we need to remove.
      // so we want to round that, which means adding 0.5 * 1<<17,
      // aka 65536. Also, we'll end up with -128 to 127 that we want
      // to encode as 0..255 by adding 128, so we'll add that before the shift
      x0 += 65536 + (128<<17);
      x1 += 65536 + (128<<17);
      x2 += 65536 + (128<<17);
      x3 += 65536 + (128<<17);
      // tried computing the shifts into temps, or'ing the temps to see
      // if any were out of range, but that was slower
      o[0] = clamp((x0+t3) >> 17);
      o[7] = clamp((x0-t3) >> 17);
      o[1] = clamp((x1+t2) >> 17);
      o[6] = clamp((x1-t2) >> 17);
      o[2] = clamp((x2+t1) >> 17);
      o[5] = clamp((x2-t1) >> 17);
      o[3] = clamp((x3+t0) >> 17);
      o[4] = clamp((x3-t0) >> 17);
   }
}


enum MARKER_none = 0xff;

// if there's a pending marker from the entropy stream, return that
// otherwise, fetch from the stream and get a marker. if there's no
// marker, return 0xff, which is never a valid marker value
ubyte get_marker(jpeg *j)
{
   ubyte x;
   if (j.marker != MARKER_none) { x = j.marker; j.marker = MARKER_none; return x; }
   x = get8u(j.s);
   if (x != 0xff) return MARKER_none;
   while (x == 0xff)
      x = get8u(j.s);
   return x;
}

// in each scan, we'll have scan_n components, and the order
// of the components is specified by order[]
bool RESTART(int x)
{
    return (x >= 0xd0) && (x <= 0xd7);
}

// after a restart interval, reset the entropy decoder and
// the dc prediction
void reset(jpeg *j)
{
   j.code_bits = 0;
   j.code_buffer = 0;
   j.nomore = 0;
   j.img_comp[0].dc_pred = j.img_comp[1].dc_pred = j.img_comp[2].dc_pred = 0;
   j.marker = MARKER_none;
   j.todo = j.restart_interval ? j.restart_interval : 0x7fffffff;
   // no more than 1<<31 MCUs if no restart_interal? that's plenty safe,
   // since we don't even allow 1<<30 pixels
}

int parse_entropy_coded_data(jpeg *z)
{
   reset(z);
   if (z.scan_n == 1) {
      int i,j;
      short data[64];
      int n = z.order[0];
      // non-interleaved data, we just need to process one block at a time,
      // in trivial scanline order
      // number of blocks to do just depends on how many actual "pixels" this
      // component has, independent of interleaved MCU blocking and such
      int w = (z.img_comp[n].x+7) >> 3;
      int h = (z.img_comp[n].y+7) >> 3;
      for (j=0; j < h; ++j) {
         for (i=0; i < w; ++i) {
            if (!decode_block(z, data, z.huff_dc.ptr+z.img_comp[n].hd, z.huff_ac.ptr+z.img_comp[n].ha, n)) return 0;
            idct_block(z.img_comp[n].data+z.img_comp[n].w2*j*8+i*8, z.img_comp[n].w2, data, z.dequant[z.img_comp[n].tq].ptr);
            // every data block is an MCU, so countdown the restart interval
            if (--z.todo <= 0) {
               if (z.code_bits < 24) grow_buffer_unsafe(z);
               // if it's NOT a restart, then just bail, so we get corrupt data
               // rather than no data
               if (!RESTART(z.marker)) return 1;
               reset(z);
            }
         }
      }
   } else { // interleaved!
      int i,j,k,x,y;
      short[64] data;
      for (j=0; j < z.img_mcu_y; ++j) {
         for (i=0; i < z.img_mcu_x; ++i) {
            // scan an interleaved mcu... process scan_n components in order
            for (k=0; k < z.scan_n; ++k) {
               int n = z.order[k];
               // scan out an mcu's worth of this component; that's just determined
               // by the basic H and V specified for the component
               for (y=0; y < z.img_comp[n].v; ++y) {
                  for (x=0; x < z.img_comp[n].h; ++x) {
                     int x2 = (i*z.img_comp[n].h + x)*8;
                     int y2 = (j*z.img_comp[n].v + y)*8;
                     if (!decode_block(z, data, z.huff_dc.ptr+z.img_comp[n].hd, z.huff_ac.ptr+z.img_comp[n].ha, n)) return 0;
                     idct_block(z.img_comp[n].data+z.img_comp[n].w2*y2+x2, z.img_comp[n].w2, data, z.dequant[z.img_comp[n].tq].ptr);
                  }
               }
            }
            // after all interleaved components, that's an interleaved MCU,
            // so now count down the restart interval
            if (--z.todo <= 0) {
               if (z.code_bits < 24) grow_buffer_unsafe(z);
               // if it's NOT a restart, then just bail, so we get corrupt data
               // rather than no data
               if (!RESTART(z.marker)) return 1;
               reset(z);
            }
         }
      }
   }
   return 1;
}

int process_marker(jpeg *z, int m)
{
   int L;
   switch (m) {
      
      case MARKER_none: // no marker found
         throw new STBImageException("Expected marker, corrupt JPEG");

      case 0xC2: // SOF - progressive
          throw new STBImageException("JPEG format not supported (progressive)");

      case 0xDD: // DRI - specify restart interval
         if (get16(z.s) != 4) 
             throw new STBImageException("Bad DRI len, corrupt JPEG");
         z.restart_interval = get16(z.s);
         return 1;

      case 0xDB: // DQT - define quantization table
         L = get16(z.s)-2;
         while (L > 0) {
            int q = get8(z.s);
            int p = q >> 4;
            int t = q & 15,i;
            if (p != 0)
               throw new STBImageException("Bad DQT type, corrupt JPEG");
            if (t > 3) 
               throw new STBImageException("Bad DQT table, corrupt JPEG");
            for (i=0; i < 64; ++i)
               z.dequant[t][dezigzag[i]] = get8u(z.s);
            L -= 65;
         }
         return L==0;

      case 0xC4: // DHT - define huffman table
         L = get16(z.s)-2;
         while (L > 0) {
            ubyte *v;
            int[16] sizes;
            int i;
            int m_ = 0;
            int q = get8(z.s);
            int tc = q >> 4;
            int th = q & 15;
            if (tc > 1 || th > 3) 
                throw new STBImageException("Bad DHT header, corrupt JPEG");
            for (i=0; i < 16; ++i) {
               sizes[i] = get8(z.s);
               m += sizes[i];
            }
            L -= 17;
            if (tc == 0) {
               if (!build_huffman(z.huff_dc.ptr+th, sizes.ptr)) return 0;
               v = z.huff_dc[th].values.ptr;
            } else {
               if (!build_huffman(z.huff_ac.ptr+th, sizes.ptr)) return 0;
               v = z.huff_ac[th].values.ptr;
            }
            for (i=0; i < m_; ++i)
               v[i] = get8u(z.s);
            L -= m_;
         }
         return L==0;

      default:
         break;
   }
   // check for comment block or APP blocks
   if ((m >= 0xE0 && m <= 0xEF) || m == 0xFE) {
      skip(z.s, get16(z.s)-2);
      return 1;
   }
   return 0;
}

// after we see SOS
int process_scan_header(jpeg *z)
{
   int i;
   int Ls = get16(z.s);
   z.scan_n = get8(z.s);
   if (z.scan_n < 1 || z.scan_n > 4 || z.scan_n > cast(int) z.s.img_n) 
      throw new STBImageException("Bad SOS component count, Corrupt JPEG");
      
   if (Ls != 6+2*z.scan_n) 
      throw new STBImageException("Bad SOS length, Corrupt JPEG");
      
   for (i=0; i < z.scan_n; ++i) {
      int id = get8(z.s), which;
      int q = get8(z.s);
      for (which = 0; which < z.s.img_n; ++which)
         if (z.img_comp[which].id == id)
            break;
      if (which == z.s.img_n) return 0;
      z.img_comp[which].hd = q >> 4;   
      if (z.img_comp[which].hd > 3) 
         throw new STBImageException("Bad DC huff, Corrupt JPEG");
      z.img_comp[which].ha = q & 15;   
      if (z.img_comp[which].ha > 3)
         throw new STBImageException("Bad AC huff, Corrupt JPEG");
      z.order[i] = which;
   }
   if (get8(z.s) != 0) 
      throw new STBImageException("Bad SOS, Corrupt JPEG");
   get8(z.s); // should be 63, but might be 0
   if (get8(z.s) != 0) 
      throw new STBImageException("Bad SOS, Corrupt JPEG");

   return 1;
}

int process_frame_header(jpeg *z, int scan)
{
   stbi *s = z.s;
   int Lf,p,i,q, h_max=1,v_max=1,c;
   Lf = get16(s);         if (Lf < 11) throw new STBImageException("Bad SOF len, Corrupt JPEG");
   p  = get8(s);          if (p != 8) throw new STBImageException("JPEG format not supported: 8-bit only"); // JPEG baseline
   s.img_y = get16(s);   if (s.img_y == 0) throw new STBImageException("No header height, JPEG format not supported: delayed height"); // Legal, but we don't handle it--but neither does IJG
   s.img_x = get16(s);   if (s.img_x == 0) throw new STBImageException("0 width, corrupt JPEG"); // JPEG requires
   c = get8(s);
   if (c != 3 && c != 1) throw new STBImageException("Bad component count, corrupt JPEG");    // JFIF requires
   s.img_n = c;
   for (i=0; i < c; ++i) {
      z.img_comp[i].data = null;
      z.img_comp[i].linebuf = null;
   }

   if (Lf != 8+3*s.img_n) throw new STBImageException("Bad SOF len, corrupt JPEG"); 

   for (i=0; i < s.img_n; ++i) {
      z.img_comp[i].id = get8(s);
      if (z.img_comp[i].id != i+1)   // JFIF requires
         if (z.img_comp[i].id != i)  // some version of jpegtran outputs non-JFIF-compliant files!
            throw new STBImageException("Bad component ID, corrupt JPEG");
      q = get8(s);
      z.img_comp[i].h = (q >> 4);  if (!z.img_comp[i].h || z.img_comp[i].h > 4) throw new STBImageException("Bad H, corrupt JPEG");
      z.img_comp[i].v = q & 15;    if (!z.img_comp[i].v || z.img_comp[i].v > 4) throw new STBImageException("Bad V, corrupt JPEG");
      z.img_comp[i].tq = get8(s);  if (z.img_comp[i].tq > 3) throw new STBImageException("Bad TQ, corrupt JPEG");
   }

   if (scan != SCAN_load) return 1;

   if ((1 << 30) / s.img_x / s.img_n < s.img_y) throw new STBImageException("Image too large to decode");

   for (i=0; i < s.img_n; ++i) {
      if (z.img_comp[i].h > h_max) h_max = z.img_comp[i].h;
      if (z.img_comp[i].v > v_max) v_max = z.img_comp[i].v;
   }

   // compute interleaved mcu info
   z.img_h_max = h_max;
   z.img_v_max = v_max;
   z.img_mcu_w = h_max * 8;
   z.img_mcu_h = v_max * 8;
   z.img_mcu_x = (s.img_x + z.img_mcu_w-1) / z.img_mcu_w;
   z.img_mcu_y = (s.img_y + z.img_mcu_h-1) / z.img_mcu_h;

   for (i=0; i < s.img_n; ++i) {
      // number of effective pixels (e.g. for non-interleaved MCU)
      z.img_comp[i].x = (s.img_x * z.img_comp[i].h + h_max-1) / h_max;
      z.img_comp[i].y = (s.img_y * z.img_comp[i].v + v_max-1) / v_max;
      // to simplify generation, we'll allocate enough memory to decode
      // the bogus oversized data from using interleaved MCUs and their
      // big blocks (e.g. a 16x16 iMCU on an image of width 33); we won't
      // discard the extra data until colorspace conversion
      z.img_comp[i].w2 = z.img_mcu_x * z.img_comp[i].h * 8;
      z.img_comp[i].h2 = z.img_mcu_y * z.img_comp[i].v * 8;
      z.img_comp[i].raw_data = malloc(z.img_comp[i].w2 * z.img_comp[i].h2+15);
      if (z.img_comp[i].raw_data == null) {
         for(--i; i >= 0; --i) {
            free(z.img_comp[i].raw_data);
            z.img_comp[i].data = null;
         }
         throw new STBImageException("Out of memory");
      }
      // align blocks for installable-idct using mmx/sse
      z.img_comp[i].data = cast(ubyte*) (( cast(size_t) z.img_comp[i].raw_data + 15) & ~15);
      z.img_comp[i].linebuf = null;
   }

   return 1;
}

// use comparisons since in some cases we handle more than one case (e.g. SOF)
bool DNL(int x) { return x == 0xdc; }
bool SOI(int x) { return x == 0xd8; }
bool EOI(int x) { return x == 0xd9; }
bool SOF(int x) { return x == 0xc0 || x == 0xc1; }
bool SOS(int x) { return x == 0xda; }

int decode_jpeg_header(jpeg *z, int scan)
{
   int m;
   z.marker = MARKER_none; // initialize cached marker to empty
   m = get_marker(z);
   if (!SOI(m)) throw new STBImageException("No SOI, corrupt JPEG");
   if (scan == SCAN_type) return 1;
   m = get_marker(z);
   while (!SOF(m)) {
      if (!process_marker(z,m)) return 0;
      m = get_marker(z);
      while (m == MARKER_none) {
         // some files have extra padding after their blocks, so ok, we'll scan
         if (at_eof(z.s)) throw new STBImageException("No SOF, corrupt JPEG");
         m = get_marker(z);
      }
   }
   if (!process_frame_header(z, scan)) return 0;
   return 1;
}

int decode_jpeg_image(jpeg *j)
{
   int m;
   j.restart_interval = 0;
   if (!decode_jpeg_header(j, SCAN_load)) return 0;
   m = get_marker(j);
   while (!EOI(m)) {
      if (SOS(m)) {
         if (!process_scan_header(j)) return 0;
         if (!parse_entropy_coded_data(j)) return 0;
         if (j.marker == MARKER_none ) {
            // handle 0s at the end of image data from IP Kamera 9060
            while (!at_eof(j.s)) {
               int x = get8(j.s);
               if (x == 255) {
                  j.marker = get8u(j.s);
                  break;
               } else if (x != 0) {
                  return 0;
               }
            }
            // if we reach eof without hitting a marker, get_marker() below will fail and we'll eventually return 0
         }
      } else {
         if (!process_marker(j, m)) return 0;
      }
      m = get_marker(j);
   }
   return 1;
}

// static jfif-centered resampling (across block boundaries)

alias resample_row_func = ubyte* function(ubyte *out_, ubyte *in0, ubyte *in1, int w, int hs);

ubyte div4(int x)
{
    return cast(ubyte)(x >> 2);
}

ubyte *resample_row_1(ubyte *out_, ubyte *in_near, ubyte *in_far, int w, int hs)
{ 
   return in_near;
}

ubyte* resample_row_v_2(ubyte *out_, ubyte *in_near, ubyte *in_far, int w, int hs)
{
   // need to generate two samples vertically for every one in input
   int i;
   for (i=0; i < w; ++i)
      out_[i] = div4(3*in_near[i] + in_far[i] + 2);
   return out_;
}

ubyte*  resample_row_h_2(ubyte *out_, ubyte *in_near, ubyte *in_far, int w, int hs)
{
   // need to generate two samples horizontally for every one in input
   int i;
   ubyte *input = in_near;

   if (w == 1) {
      // if only one sample, can't do any interpolation
      out_[0] = out_[1] = input[0];
      return out_;
   }

   out_[0] = input[0];
   out_[1] = div4(input[0]*3 + input[1] + 2);
   for (i=1; i < w-1; ++i) {
      int n = 3*input[i]+2;
      out_[i*2+0] = div4(n+input[i-1]);
      out_[i*2+1] = div4(n+input[i+1]);
   }
   out_[i*2+0] = div4(input[w-2]*3 + input[w-1] + 2);
   out_[i*2+1] = input[w-1];

   return out_;
}

ubyte div16(int x)
{
    return cast(ubyte)(x >> 4);
}


ubyte *resample_row_hv_2(ubyte *out_, ubyte *in_near, ubyte *in_far, int w, int hs)
{
   // need to generate 2x2 samples for every one in input
   int i,t0,t1;
   if (w == 1) {
      out_[0] = out_[1] = div4(3*in_near[0] + in_far[0] + 2);
      return out_;
   }

   t1 = 3*in_near[0] + in_far[0];
   out_[0] = div4(t1+2);
   for (i=1; i < w; ++i) {
      t0 = t1;
      t1 = 3*in_near[i]+in_far[i];
      out_[i*2-1] = div16(3*t0 + t1 + 8);
      out_[i*2  ] = div16(3*t1 + t0 + 8);
   }
   out_[w*2-1] = div4(t1+2);

   return out_;
}

ubyte *resample_row_generic(ubyte *out_, ubyte *in_near, ubyte *in_far, int w, int hs)
{
   // resample with nearest-neighbor
   int i,j;
   in_far = in_far;
   for (i=0; i < w; ++i)
      for (j=0; j < hs; ++j)
         out_[i*hs+j] = in_near[i];
   return out_;
}

int float2fixed(double x)
{
    return cast(int)((x) * 65536 + 0.5);
}

// 0.38 seconds on 3*anemones.jpg   (0.25 with processor = Pro)
// VC6 without processor=Pro is generating multiple LEAs per multiply!
void YCbCr_to_RGB_row(ubyte *out_, const ubyte *y, const ubyte *pcb, const ubyte *pcr, int count, int step)
{
   int i;
   for (i=0; i < count; ++i) {
      int y_fixed = (y[i] << 16) + 32768; // rounding
      int r,g,b;
      int cr = pcr[i] - 128;
      int cb = pcb[i] - 128;
      r = y_fixed + cr*float2fixed(1.40200f);
      g = y_fixed - cr*float2fixed(0.71414f) - cb*float2fixed(0.34414f);
      b = y_fixed                            + cb*float2fixed(1.77200f);
      r >>= 16;
      g >>= 16;
      b >>= 16;
      if (cast(uint) r > 255) { if (r < 0) r = 0; else r = 255; }
      if (cast(uint) g > 255) { if (g < 0) g = 0; else g = 255; }
      if (cast(uint) b > 255) { if (b < 0) b = 0; else b = 255; }
      out_[0] = cast(ubyte)r;
      out_[1] = cast(ubyte)g;
      out_[2] = cast(ubyte)b;
      out_[3] = 255;
      out_ += step;
   }
}

// clean up the temporary component buffers
void cleanup_jpeg(jpeg *j)
{
   int i;
   for (i=0; i < j.s.img_n; ++i) {
      if (j.img_comp[i].data) {
         free(j.img_comp[i].raw_data);
         j.img_comp[i].data = null;
      }
      if (j.img_comp[i].linebuf) {
         free(j.img_comp[i].linebuf);
         j.img_comp[i].linebuf = null;
      }
   }
}

struct stbi_resample
{
   resample_row_func resample;
   ubyte* line0;
   ubyte* line1;
   int hs,vs;   // expansion factor in each axis
   int w_lores; // horizontal pixels pre-expansion 
   int ystep;   // how far through vertical expansion we are
   int ypos;    // which pre-expansion row we're on
} ;

ubyte *load_jpeg_image(jpeg *z, int *out_x, int *out_y, int *comp, int req_comp)
{
   int n, decode_n;
   // validate req_comp
   if (req_comp < 0 || req_comp > 4) 
       throw new STBImageException("Internal error: bad req_comp");
   z.s.img_n = 0;

   // load a jpeg image from whichever source
   if (!decode_jpeg_image(z)) { cleanup_jpeg(z); return null; }

   // determine actual number of components to generate
   n = req_comp ? req_comp : z.s.img_n;

   if (z.s.img_n == 3 && n < 3)
      decode_n = 1;
   else
      decode_n = z.s.img_n;

   // resample and color-convert
   {
      int k;
      uint i,j;
      ubyte *output;
      ubyte *coutput[4];

      stbi_resample res_comp[4];

      for (k=0; k < decode_n; ++k) {
         stbi_resample *r = &res_comp[k];

         // allocate line buffer big enough for upsampling off the edges
         // with upsample factor of 4
         z.img_comp[k].linebuf = cast(ubyte *) malloc(z.s.img_x + 3);
         if (!z.img_comp[k].linebuf) 
         { 
             cleanup_jpeg(z); 
             throw new STBImageException("Out of memory");
         }

         r.hs      = z.img_h_max / z.img_comp[k].h;
         r.vs      = z.img_v_max / z.img_comp[k].v;
         r.ystep   = r.vs >> 1;
         r.w_lores = (z.s.img_x + r.hs-1) / r.hs;
         r.ypos    = 0;
         r.line0   = r.line1 = z.img_comp[k].data;

         if      (r.hs == 1 && r.vs == 1) r.resample = &resample_row_1;
         else if (r.hs == 1 && r.vs == 2) r.resample = &resample_row_v_2;
         else if (r.hs == 2 && r.vs == 1) r.resample = &resample_row_h_2;
         else if (r.hs == 2 && r.vs == 2) r.resample = &resample_row_hv_2;
         else                               r.resample = &resample_row_generic;
      }

      // can't error after this so, this is safe
      output = cast(ubyte *) malloc(n * z.s.img_x * z.s.img_y + 1);
      if (!output) { cleanup_jpeg(z); throw new STBImageException("Out of memory"); }

      // now go ahead and resample
      for (j=0; j < z.s.img_y; ++j) {
         ubyte *out_ = output + n * z.s.img_x * j;
         for (k=0; k < decode_n; ++k) {
            stbi_resample *r = &res_comp[k];
            int y_bot = r.ystep >= (r.vs >> 1);
            coutput[k] = r.resample(z.img_comp[k].linebuf,
                                     y_bot ? r.line1 : r.line0,
                                     y_bot ? r.line0 : r.line1,
                                     r.w_lores, r.hs);
            if (++r.ystep >= r.vs) {
               r.ystep = 0;
               r.line0 = r.line1;
               if (++r.ypos < z.img_comp[k].y)
                  r.line1 += z.img_comp[k].w2;
            }
         }
         if (n >= 3) {
            ubyte *y = coutput[0];
            if (z.s.img_n == 3) {
               YCbCr_to_RGB_row(out_, y, coutput[1], coutput[2], z.s.img_x, n);
            } else
               for (i=0; i < z.s.img_x; ++i) {
                  out_[0] = out_[1] = out_[2] = y[i];
                  out_[3] = 255; // not used if n==3
                  out_ += n;
               }
         } else {
            ubyte *y = coutput[0];
            if (n == 1)
               for (i=0; i < z.s.img_x; ++i) out_[i] = y[i];
            else
               for (i=0; i < z.s.img_x; ++i) *out_++ = y[i], *out_++ = 255;
         }
      }
      cleanup_jpeg(z);
      *out_x = z.s.img_x;
      *out_y = z.s.img_y;
      if (comp) *comp  = z.s.img_n; // report original components, not output
      return output;
   }
}

char *stbi_jpeg_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   jpeg j;
   j.s = s;
   return cast(char*)load_jpeg_image(&j, x,y,comp,req_comp);
}

int stbi_jpeg_test(stbi *s)
{
   int r;
   jpeg j;
   j.s = s;
   r = decode_jpeg_header(&j, SCAN_type);
   stbi_rewind(s);
   return r;
}

int stbi_jpeg_info_raw(jpeg *j, int *x, int *y, int *comp)
{
   if (!decode_jpeg_header(j, SCAN_header)) {
      stbi_rewind( j.s );
      return 0;
   }
   if (x) *x = j.s.img_x;
   if (y) *y = j.s.img_y;
   if (comp) *comp = j.s.img_n;
   return 1;
}

int stbi_jpeg_info(stbi *s, int *x, int *y, int *comp)
{
   jpeg j;
   j.s = s;
   return stbi_jpeg_info_raw(&j, x, y, comp);
}

// public domain zlib decode    v0.2  Sean Barrett 2006-11-18
//    simple implementation
//      - all input must be provided in an upfront buffer
//      - all output is written to a single output buffer (can malloc/realloc)
//    performance
//      - fast huffman

// fast-way is faster to check than jpeg huffman, but slow way is slower
enum ZFAST_BITS = 9; // accelerate all cases in default tables
enum ZFAST_MASK = ((1 << ZFAST_BITS) - 1);

// zlib-style huffman encoding
// (jpegs packs from left, zlib from right, so can't share code)
struct zhuffman
{
   ushort[1 << ZFAST_BITS] fast;
   ushort[16] firstcode;
   int[17] maxcode;
   ushort[16] firstsymbol;
   ubyte[288] size;
   ushort[288] value;
} ;

int bitreverse16(int n)
{
  n = ((n & 0xAAAA) >>  1) | ((n & 0x5555) << 1);
  n = ((n & 0xCCCC) >>  2) | ((n & 0x3333) << 2);
  n = ((n & 0xF0F0) >>  4) | ((n & 0x0F0F) << 4);
  n = ((n & 0xFF00) >>  8) | ((n & 0x00FF) << 8);
  return n;
}

int bit_reverse(int v, int bits)
{
   assert(bits <= 16);
   // to bit reverse n bits, reverse 16 and shift
   // e.g. 11 bits, bit reverse and shift away 5
   return bitreverse16(v) >> (16-bits);
}

int zbuild_huffman(zhuffman *z, ubyte *sizelist, int num)
{
   int i,k=0;
   int code;
   int[16] next_code;
   int[17] sizes;

   // DEFLATE spec for generating codes
   memset(sizes.ptr, 0, sizes.sizeof);
   memset(z.fast.ptr, 255, z.fast.sizeof);
   for (i=0; i < num; ++i) 
      ++sizes[sizelist[i]];
   sizes[0] = 0;
   for (i=1; i < 16; ++i)
      assert(sizes[i] <= (1 << i));
   code = 0;
   for (i=1; i < 16; ++i) {
      next_code[i] = code;
      z.firstcode[i] = cast(ushort) code;
      z.firstsymbol[i] = cast(ushort) k;
      code = (code + sizes[i]);
      if (sizes[i])
         if (code-1 >= (1 << i)) 
            throw new STBImageException("Bad codelength, corrupt JPEG");
      z.maxcode[i] = code << (16-i); // preshift for inner loop
      code <<= 1;
      k += sizes[i];
   }
   z.maxcode[16] = 0x10000; // sentinel
   for (i=0; i < num; ++i) {
      int s = sizelist[i];
      if (s) {
         int c = next_code[s] - z.firstcode[s] + z.firstsymbol[s];
         z.size[c] = cast(ubyte)s;
         z.value[c] = cast(ushort)i;
         if (s <= ZFAST_BITS) {
            int k_ = bit_reverse(next_code[s],s);
            while (k_ < (1 << ZFAST_BITS)) {
               z.fast[k_] = cast(ushort) c;
               k_ += (1 << s);
            }
         }
         ++next_code[s];
      }
   }
   return 1;
}

// zlib-from-memory implementation for PNG reading
//    because PNG allows splitting the zlib stream arbitrarily,
//    and it's annoying structurally to have PNG call ZLIB call PNG,
//    we require PNG read all the IDATs and combine them into a single
//    memory buffer

struct zbuf
{
   ubyte *zbuffer;
   ubyte *zbuffer_end;
   int num_bits;
   uint code_buffer;

   char *zout;
   char *zout_start;
   char *zout_end;
   int   z_expandable;

   zhuffman z_length, z_distance;
} ;

int zget8(zbuf *z)
{
   if (z.zbuffer >= z.zbuffer_end) return 0;
   return *z.zbuffer++;
}

void fill_bits(zbuf *z)
{
   do {
      assert(z.code_buffer < (1U << z.num_bits));
      z.code_buffer |= zget8(z) << z.num_bits;
      z.num_bits += 8;
   } while (z.num_bits <= 24);
}

uint zreceive(zbuf *z, int n)
{
   uint k;
   if (z.num_bits < n) fill_bits(z);
   k = z.code_buffer & ((1 << n) - 1);
   z.code_buffer >>= n;
   z.num_bits -= n;
   return k;   
}

int zhuffman_decode(zbuf *a, zhuffman *z)
{
   int b,s,k;
   if (a.num_bits < 16) fill_bits(a);
   b = z.fast[a.code_buffer & ZFAST_MASK];
   if (b < 0xffff) {
      s = z.size[b];
      a.code_buffer >>= s;
      a.num_bits -= s;
      return z.value[b];
   }

   // not resolved by fast table, so compute it the slow way
   // use jpeg approach, which requires MSbits at top
   k = bit_reverse(a.code_buffer, 16);
   for (s=ZFAST_BITS+1; ; ++s)
      if (k < z.maxcode[s])
         break;
   if (s == 16) return -1; // invalid code!
   // code size is s, so:
   b = (k >> (16-s)) - z.firstcode[s] + z.firstsymbol[s];
   assert(z.size[b] == s);
   a.code_buffer >>= s;
   a.num_bits -= s;
   return z.value[b];
}

int expand(zbuf *z, int n)  // need to make room for n bytes
{
   char *q;
   int cur, limit;
   if (!z.z_expandable) 
      throw new STBImageException("Output buffer limit, corrupt PNG");
   cur   = cast(int) (z.zout     - z.zout_start);
   limit = cast(int) (z.zout_end - z.zout_start);
   while (cur + n > limit)
      limit *= 2;
   q = cast(char *) realloc(z.zout_start, limit);
   if (q == null) 
      throw new STBImageException("Out of memory");
   z.zout_start = q;
   z.zout       = q + cur;
   z.zout_end   = q + limit;
   return 1;
}

static immutable int length_base[31] = [
   3,4,5,6,7,8,9,10,11,13,
   15,17,19,23,27,31,35,43,51,59,
   67,83,99,115,131,163,195,227,258,0,0 ];

static immutable int length_extra[31]= 
[ 0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0,0,0 ];

static immutable int dist_base[32] = [ 1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,
257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577,0,0];

static immutable int dist_extra[32] =
[ 0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13];

int parse_huffman_block(zbuf *a)
{
   for(;;) {
      int z = zhuffman_decode(a, &a.z_length);
      if (z < 256) {
         if (z < 0) 
             throw new STBImageException("Bad Huffman code, corrupt PNG");             
         if (a.zout >= a.zout_end) if (!expand(a, 1)) return 0;
         *a.zout++ = cast(char) z;
      } else {
         ubyte *p;
         int len,dist;
         if (z == 256) return 1;
         z -= 257;
         len = length_base[z];
         if (length_extra[z]) len += zreceive(a, length_extra[z]);
         z = zhuffman_decode(a, &a.z_distance);
         if (z < 0) throw new STBImageException("Bad Huffman code, corrupt PNG");
         dist = dist_base[z];
         if (dist_extra[z]) dist += zreceive(a, dist_extra[z]);
         if (a.zout - a.zout_start < dist) throw new STBImageException("Bad dist, corrupt PNG");
         if (a.zout + len > a.zout_end) if (!expand(a, len)) return 0;
         p = cast(ubyte *) (a.zout - dist);
         while (len--)
            *a.zout++ = *p++;
      }
   }
}

int compute_huffman_codes(zbuf *a)
{
   static immutable ubyte length_dezigzag[19] = [ 16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15 ];
   zhuffman z_codelength;
   ubyte lencodes[286+32+137];//padding for maximum single op
   ubyte codelength_sizes[19];
   int i,n;

   int hlit  = zreceive(a,5) + 257;
   int hdist = zreceive(a,5) + 1;
   int hclen = zreceive(a,4) + 4;

   memset(codelength_sizes.ptr, 0, codelength_sizes.sizeof);
   for (i=0; i < hclen; ++i) {
      int s = zreceive(a,3);
      codelength_sizes[length_dezigzag[i]] = cast(ubyte) s;
   }
   if (!zbuild_huffman(&z_codelength, codelength_sizes.ptr, 19)) return 0;

   n = 0;
   while (n < hlit + hdist) {
      int c = zhuffman_decode(a, &z_codelength);
      assert(c >= 0 && c < 19);
      if (c < 16)
         lencodes[n++] = cast(ubyte) c;
      else if (c == 16) {
         c = zreceive(a,2)+3;
         memset(lencodes.ptr+n, lencodes[n-1], c);
         n += c;
      } else if (c == 17) {
         c = zreceive(a,3)+3;
         memset(lencodes.ptr+n, 0, c);
         n += c;
      } else {
         assert(c == 18);
         c = zreceive(a,7)+11;
         memset(lencodes.ptr+n, 0, c);
         n += c;
      }
   }
   if (n != hlit+hdist) throw new STBImageException("Bad codelengths, corrupt PNG");
   if (!zbuild_huffman(&a.z_length, lencodes.ptr, hlit)) return 0;
   if (!zbuild_huffman(&a.z_distance, lencodes.ptr+hlit, hdist)) return 0;
   return 1;
}

int parse_uncompressed_block(zbuf *a)
{
   ubyte header[4];
   int len,nlen,k;
   if (a.num_bits & 7)
      zreceive(a, a.num_bits & 7); // discard
   // drain the bit-packed data into header
   k = 0;
   while (a.num_bits > 0) {
      header[k++] = cast(ubyte) (a.code_buffer & 255); // wtf this warns?
      a.code_buffer >>= 8;
      a.num_bits -= 8;
   }
   assert(a.num_bits == 0);
   // now fill header the normal way
   while (k < 4)
      header[k++] = cast(ubyte) zget8(a);
   len  = header[1] * 256 + header[0];
   nlen = header[3] * 256 + header[2];
   if (nlen != (len ^ 0xffff)) throw new STBImageException("Zlib corrupt, corrupt PNG");
   if (a.zbuffer + len > a.zbuffer_end) throw new STBImageException("Read past buffer, corrupt PNG");
   if (a.zout + len > a.zout_end)
      if (!expand(a, len)) return 0;
   memcpy(a.zout, a.zbuffer, len);
   a.zbuffer += len;
   a.zout += len;
   return 1;
}

int parse_zlib_header(zbuf *a)
{
   int cmf   = zget8(a);
   int cm    = cmf & 15;
   /* int cinfo = cmf >> 4; */
   int flg   = zget8(a);
   if ((cmf*256+flg) % 31 != 0) throw new STBImageException("Bad zlib header, corrupt PNG"); // zlib spec
   if (flg & 32) throw new STBImageException("No preset dict, corrupt PNG"); // preset dictionary not allowed in png
   if (cm != 8) throw new STBImageException("Bad compression, corrupt PNG");  // DEFLATE required for png
   // window = 1 << (8 + cinfo)... but who cares, we fully buffer output
   return 1;
}

// @TODO: should statically initialize these for optimal thread safety
__gshared static ubyte[288] default_length;
__gshared static ubyte[32] default_distance;

void init_defaults()
{
   int i;   // use <= to match clearly with spec
   for (i=0; i <= 143; ++i)     default_length[i]   = 8;
   for (   ; i <= 255; ++i)     default_length[i]   = 9;
   for (   ; i <= 279; ++i)     default_length[i]   = 7;
   for (   ; i <= 287; ++i)     default_length[i]   = 8;

   for (i=0; i <=  31; ++i)     default_distance[i] = 5;
}

int stbi_png_partial; // a quick hack to only allow decoding some of a PNG... I should implement real streaming support instead
int parse_zlib(zbuf *a, int parse_header)
{
   int final_, type;
   if (parse_header)
      if (!parse_zlib_header(a)) return 0;
   a.num_bits = 0;
   a.code_buffer = 0;
   do {
      final_ = zreceive(a,1);
      type = zreceive(a,2);
      if (type == 0) {
         if (!parse_uncompressed_block(a)) return 0;
      } else if (type == 3) {
         return 0;
      } else {
         if (type == 1) {
            // use fixed code lengths
            if (!default_distance[31]) init_defaults();
            if (!zbuild_huffman(&a.z_length  , default_length.ptr  , 288)) return 0;
            if (!zbuild_huffman(&a.z_distance, default_distance.ptr,  32)) return 0;
         } else {
            if (!compute_huffman_codes(a)) return 0;
         }
         if (!parse_huffman_block(a)) return 0;
      }
      if (stbi_png_partial && a.zout - a.zout_start > 65536)
         break;
   } while (!final_);
   return 1;
}

int do_zlib(zbuf *a, char *obuf, int olen, int exp, int parse_header)
{
   a.zout_start = obuf;
   a.zout       = obuf;
   a.zout_end   = obuf + olen;
   a.z_expandable = exp;

   return parse_zlib(a, parse_header);
}

char *stbi_zlib_decode_malloc_guesssize(const char *buffer, int len, int initial_size, int *outlen)
{
   zbuf a;
   char *p = cast(char *) malloc(initial_size);
   if (p == null) return null;
   a.zbuffer = cast(ubyte *) buffer;
   a.zbuffer_end = cast(ubyte *) buffer + len;
   if (do_zlib(&a, p, initial_size, 1, 1)) {
      if (outlen) *outlen = cast(int) (a.zout - a.zout_start);
      return a.zout_start;
   } else {
      free(a.zout_start);
      return null;
   }
}

char *stbi_zlib_decode_malloc(const(char) *buffer, int len, int *outlen)
{
   return stbi_zlib_decode_malloc_guesssize(buffer, len, 16384, outlen);
}

char *stbi_zlib_decode_malloc_guesssize_headerflag(const char *buffer, int len, int initial_size, int *outlen, int parse_header)
{
   zbuf a;
   char *p = cast(char *) malloc(initial_size);
   if (p == null) return null;
   a.zbuffer = cast(ubyte *) buffer;
   a.zbuffer_end = cast(ubyte *) buffer + len;
   if (do_zlib(&a, p, initial_size, 1, parse_header)) {
      if (outlen) *outlen = cast(int) (a.zout - a.zout_start);
      return a.zout_start;
   } else {
      free(a.zout_start);
      return null;
   }
}

int stbi_zlib_decode_buffer(char *obuffer, int olen, const(char) *ibuffer, int ilen)
{
   zbuf a;
   a.zbuffer = cast(ubyte *) ibuffer;
   a.zbuffer_end = cast(ubyte *) ibuffer + ilen;
   if (do_zlib(&a, obuffer, olen, 0, 1))
      return cast(int) (a.zout - a.zout_start);
   else
      return -1;
}

char *stbi_zlib_decode_noheader_malloc(const(char) *buffer, int len, int *outlen)
{
   zbuf a;
   char *p = cast(char *) malloc(16384);
   if (p == null) return null;
   a.zbuffer = cast(ubyte *) buffer;
   a.zbuffer_end = cast(ubyte *) buffer+len;
   if (do_zlib(&a, p, 16384, 1, 0)) {
      if (outlen) *outlen = cast(int) (a.zout - a.zout_start);
      return a.zout_start;
   } else {
      free(a.zout_start);
      return null;
   }
}

int stbi_zlib_decode_noheader_buffer(char *obuffer, int olen, const char *ibuffer, int ilen)
{
   zbuf a;
   a.zbuffer = cast(ubyte *) ibuffer;
   a.zbuffer_end = cast(ubyte *) ibuffer + ilen;
   if (do_zlib(&a, obuffer, olen, 0, 0))
      return cast(int) (a.zout - a.zout_start);
   else
      return -1;
}

// public domain "baseline" PNG decoder   v0.10  Sean Barrett 2006-11-18
//    simple implementation
//      - only 8-bit samples
//      - no CRC checking
//      - allocates lots of intermediate memory
//        - avoids problem of streaming data between subsystems
//        - avoids explicit window management
//    performance
//      - uses stb_zlib, a PD zlib implementation with fast huffman decoding


struct chunk
{
   uint length;
   uint type;
}

uint PNG_TYPE(ubyte a, ubyte b, ubyte c, ubyte d)
{
   return (a << 24) + (b << 16) + (c << 8) + d;
}

chunk get_chunk_header(stbi *s)
{
   chunk c;
   c.length = get32(s);
   c.type   = get32(s);
   return c;
}

static int check_png_header(stbi *s)
{
   static immutable ubyte[8] png_sig = [ 137,80,78,71,13,10,26,10 ];
   int i;
   for (i=0; i < 8; ++i)
      if (get8u(s) != png_sig[i]) throw new STBImageException("Bad PNG sig, not a PNG");
   return 1;
}

struct png
{
   stbi *s;
   ubyte *idata;
   ubyte *expanded;
   ubyte *out_;
}


enum : int 
{
   F_none=0, F_sub=1, F_up=2, F_avg=3, F_paeth=4,
   F_avg_first, F_paeth_first
}

static immutable ubyte[5] first_row_filter =
[
   F_none, F_sub, F_none, F_avg_first, F_paeth_first
];

static int paeth(int a, int b, int c)
{
   int p = a + b - c;
   int pa = abs(p-a);
   int pb = abs(p-b);
   int pc = abs(p-c);
   if (pa <= pb && pa <= pc) return a;
   if (pb <= pc) return b;
   return c;
}

// create the png data from post-deflated data
static int create_png_image_raw(png *a, ubyte *raw, uint raw_len, int out_n, uint x, uint y)
{
   stbi *s = a.s;
   uint i,j,stride = x*out_n;
   int k;
   int img_n = s.img_n; // copy it into a local for later
   assert(out_n == s.img_n || out_n == s.img_n+1);
   if (stbi_png_partial) y = 1;
   a.out_ = cast(ubyte *) malloc(x * y * out_n);
   if (!a.out_) throw new STBImageException("Out of memory");
   if (!stbi_png_partial) {
      if (s.img_x == x && s.img_y == y) {
         if (raw_len != (img_n * x + 1) * y) throw new STBImageException("Not enough pixels, corrupt PNG");
      } else { // interlaced:
         if (raw_len < (img_n * x + 1) * y) throw new STBImageException("Not enough pixels, corrupt PNG");
      }
   }
   for (j=0; j < y; ++j) {
      ubyte *cur = a.out_ + stride*j;
      ubyte *prior = cur - stride;
      int filter = *raw++;
      if (filter > 4) throw new STBImageException("Invalid filter, corrupt PNG");
      // if first row, use special filter that doesn't sample previous row
      if (j == 0) filter = first_row_filter[filter];
      // handle first pixel explicitly
      for (k=0; k < img_n; ++k) {
         switch (filter) {
            case F_none       : cur[k] = raw[k]; break;
            case F_sub        : cur[k] = raw[k]; break;
            case F_up         : cur[k] = cast(ubyte)(raw[k] + prior[k]); break;
            case F_avg        : cur[k] = cast(ubyte)(raw[k] + (prior[k]>>1)); break;
            case F_paeth      : cur[k] = cast(ubyte) (raw[k] + paeth(0,prior[k],0)); break;
            case F_avg_first  : cur[k] = raw[k]; break;
            case F_paeth_first: cur[k] = raw[k]; break;
            default: break;
         }
      }
      if (img_n != out_n) cur[img_n] = 255;
      raw += img_n;
      cur += out_n;
      prior += out_n;
      // this is a little gross, so that we don't switch per-pixel or per-component
      if (img_n == out_n) {

         for (i=x-1; i >= 1; --i, raw+=img_n,cur+=img_n,prior+=img_n)
            for (k=0; k < img_n; ++k)
            {
               switch (filter) {
                  case F_none:  cur[k] = raw[k]; break;
                  case F_sub:   cur[k] = cast(ubyte)(raw[k] + cur[k-img_n]); break;
                  case F_up:    cur[k] = cast(ubyte)(raw[k] + prior[k]); break;
                  case F_avg:   cur[k] = cast(ubyte)(raw[k] + ((prior[k] + cur[k-img_n])>>1)); break;
                  case F_paeth:  cur[k] = cast(ubyte) (raw[k] + paeth(cur[k-img_n],prior[k],prior[k-img_n])); break;
                  case F_avg_first:    cur[k] = cast(ubyte)(raw[k] + (cur[k-img_n] >> 1)); break;
                  case F_paeth_first:  cur[k] = cast(ubyte) (raw[k] + paeth(cur[k-img_n],0,0)); break;
                  default: break;
               }
            }
      } else {
         assert(img_n+1 == out_n);

         for (i=x-1; i >= 1; --i, cur[img_n]=255,raw+=img_n,cur+=out_n,prior+=out_n)
            for (k=0; k < img_n; ++k)
            {
               switch (filter) {
                  case F_none:  cur[k] = raw[k]; break;
                  case F_sub:   cur[k] = cast(ubyte)(raw[k] + cur[k-out_n]); break;
                  case F_up:    cur[k] = cast(ubyte)(raw[k] + prior[k]); break;
                  case F_avg:   cur[k] = cast(ubyte)(raw[k] + ((prior[k] + cur[k-out_n])>>1)); break;
                  case F_paeth:  cur[k] = cast(ubyte) (raw[k] + paeth(cur[k-out_n],prior[k],prior[k-out_n])); break;
                  case F_avg_first:    cur[k] = cast(ubyte)(raw[k] + (cur[k-out_n] >> 1)); break;
                  case F_paeth_first:  cur[k] = cast(ubyte) (raw[k] + paeth(cur[k-out_n],0,0)); break;
                  default: break;
               }
            }
      }
   }
   return 1;
}

int create_png_image(png *a, ubyte *raw, uint raw_len, int out_n, int interlaced)
{
   ubyte *final_;
   int p;
   int save;
   if (!interlaced)
      return create_png_image_raw(a, raw, raw_len, out_n, a.s.img_x, a.s.img_y);
   save = stbi_png_partial;
   stbi_png_partial = 0;

   // de-interlacing
   final_ = cast(ubyte *) malloc(a.s.img_x * a.s.img_y * out_n);
   for (p=0; p < 7; ++p) {
      int xorig[] = [ 0,4,0,2,0,1,0 ];
      int yorig[] = [ 0,0,4,0,2,0,1 ];
      int xspc[]  = [ 8,8,4,4,2,2,1 ];
      int yspc[]  = [ 8,8,8,4,4,2,2 ];
      int i,j,x,y;
      // pass1_x[4] = 0, pass1_x[5] = 1, pass1_x[12] = 1
      x = (a.s.img_x - xorig[p] + xspc[p]-1) / xspc[p];
      y = (a.s.img_y - yorig[p] + yspc[p]-1) / yspc[p];
      if (x && y) {
         if (!create_png_image_raw(a, raw, raw_len, out_n, x, y)) {
            free(final_);
            return 0;
         }
         for (j=0; j < y; ++j)
            for (i=0; i < x; ++i)
               memcpy(final_ + (j*yspc[p]+yorig[p])*a.s.img_x*out_n + (i*xspc[p]+xorig[p])*out_n,
                      a.out_ + (j*x+i)*out_n, out_n);
         free(a.out_);
         raw += (x*out_n+1)*y;
         raw_len -= (x*out_n+1)*y;
      }
   }
   a.out_ = final_;

   stbi_png_partial = save;
   return 1;
}

static int compute_transparency(png *z, ubyte tc[3], int out_n)
{
   stbi *s = z.s;
   uint i, pixel_count = s.img_x * s.img_y;
   ubyte *p = z.out_;

   // compute color-based transparency, assuming we've
   // already got 255 as the alpha value in the output
   assert(out_n == 2 || out_n == 4);

   if (out_n == 2) {
      for (i=0; i < pixel_count; ++i) {
         p[1] = (p[0] == tc[0] ? 0 : 255);
         p += 2;
      }
   } else {
      for (i=0; i < pixel_count; ++i) {
         if (p[0] == tc[0] && p[1] == tc[1] && p[2] == tc[2])
            p[3] = 0;
         p += 4;
      }
   }
   return 1;
}

int expand_palette(png *a, ubyte *palette, int len, int pal_img_n)
{
   uint i, pixel_count = a.s.img_x * a.s.img_y;
   ubyte *p;
   ubyte *temp_out;
   ubyte *orig = a.out_;

   p = cast(ubyte *) malloc(pixel_count * pal_img_n);
   if (p == null) 
      throw new STBImageException("Out of memory");

   // between here and free(out) below, exitting would leak
   temp_out = p;

   if (pal_img_n == 3) {
      for (i=0; i < pixel_count; ++i) {
         int n = orig[i]*4;
         p[0] = palette[n  ];
         p[1] = palette[n+1];
         p[2] = palette[n+2];
         p += 3;
      }
   } else {
      for (i=0; i < pixel_count; ++i) {
         int n = orig[i]*4;
         p[0] = palette[n  ];
         p[1] = palette[n+1];
         p[2] = palette[n+2];
         p[3] = palette[n+3];
         p += 4;
      }
   }
   free(a.out_);
   a.out_ = temp_out;

   return 1;
}

__gshared int stbi_unpremultiply_on_load = 0;
__gshared int stbi_de_iphone_flag = 0;

void stbi_set_unpremultiply_on_load(int flag_true_if_should_unpremultiply)
{
   stbi_unpremultiply_on_load = flag_true_if_should_unpremultiply;
}
void stbi_convert_iphone_png_to_rgb(int flag_true_if_should_convert)
{
   stbi_de_iphone_flag = flag_true_if_should_convert;
}

void stbi_de_iphone(png *z)
{
   stbi *s = z.s;
   uint i, pixel_count = s.img_x * s.img_y;
   ubyte *p = z.out_;

   if (s.img_out_n == 3) {  // convert bgr to rgb
      for (i=0; i < pixel_count; ++i) {
         ubyte t = p[0];
         p[0] = p[2];
         p[2] = t;
         p += 3;
      }
   } else {
      assert(s.img_out_n == 4);
      if (stbi_unpremultiply_on_load) {
         // convert bgr to rgb and unpremultiply
         for (i=0; i < pixel_count; ++i) {
            ubyte a = p[3];
            ubyte t = p[0];
            if (a) {
               p[0] = cast(ubyte)(p[2] * 255 / a);
               p[1] = cast(ubyte)(p[1] * 255 / a);
               p[2] = cast(ubyte)( t   * 255 / a);
            } else {
               p[0] = p[2];
               p[2] = t;
            } 
            p += 4;
         }
      } else {
         // convert bgr to rgb
         for (i=0; i < pixel_count; ++i) {
            ubyte t = p[0];
            p[0] = p[2];
            p[2] = t;
            p += 4;
         }
      }
   }
}

int parse_png_file(png *z, int scan, int req_comp)
{
   ubyte[1024] palette;
   ubyte pal_img_n=0;
   ubyte has_trans=0;
   ubyte tc[3];
   uint ioff=0, idata_limit=0, i, pal_len=0;
   int first=1,k,interlace=0, iphone=0;
   stbi *s = z.s;

   z.expanded = null;
   z.idata = null;
   z.out_ = null;

   if (!check_png_header(s)) return 0;

   if (scan == SCAN_type) return 1;

   for (;;) {
      chunk c = get_chunk_header(s);
      switch (c.type) {
         case PNG_TYPE('C','g','B','I'):
            iphone = stbi_de_iphone_flag;
            skip(s, c.length);
            break;
         case PNG_TYPE('I','H','D','R'): {
            int depth,color,comp,filter;
            if (!first) throw new STBImageException("Multiple IHDR, corrupt PNG");
            first = 0;
            if (c.length != 13) throw new STBImageException("Bad IHDR len, corrupt PNG");
            s.img_x = get32(s); if (s.img_x > (1 << 24)) throw new STBImageException("Very large image (corrupt?)");
            s.img_y = get32(s); if (s.img_y > (1 << 24)) throw new STBImageException("Very large image (corrupt?)");
            depth = get8(s);  if (depth != 8)        throw new STBImageException("8bit only, PNG not supported: 8-bit only");
            color = get8(s);  if (color > 6)         throw new STBImageException("Bad ctype, corrupt PNG");
            if (color == 3) pal_img_n = 3; else if (color & 1) throw new STBImageException("Bad ctype, corrupt PNG");
            comp  = get8(s);  if (comp) throw new STBImageException("Bad comp method, corrupt PNG");
            filter= get8(s);  if (filter) throw new STBImageException("Bad filter method, corrupt PNG");
            interlace = get8(s); if (interlace>1) throw new STBImageException("Bad interlace method, corrupt PNG");
            if (!s.img_x || !s.img_y) throw new STBImageException("0-pixel image, corrupt PNG");
            if (!pal_img_n) {
               s.img_n = (color & 2 ? 3 : 1) + (color & 4 ? 1 : 0);
               if ((1 << 30) / s.img_x / s.img_n < s.img_y) throw new STBImageException("Image too large to decode");
               if (scan == SCAN_header) return 1;
            } else {
               // if paletted, then pal_n is our final components, and
               // img_n is # components to decompress/filter.
               s.img_n = 1;
               if ((1 << 30) / s.img_x / 4 < s.img_y) throw new STBImageException("Too large, corrupt PNG");
               // if SCAN_header, have to scan to see if we have a tRNS
            }
            break;
         }

         case PNG_TYPE('P','L','T','E'):  {
            if (first) throw new STBImageException("first not IHDR, corrupt PNG");
            if (c.length > 256*3) throw new STBImageException("invalid PLTE, corrupt PNG");
            pal_len = c.length / 3;
            if (pal_len * 3 != c.length) throw new STBImageException("invalid PLTE, corrupt PNG");
            for (i=0; i < pal_len; ++i) {
               palette[i*4+0] = get8u(s);
               palette[i*4+1] = get8u(s);
               palette[i*4+2] = get8u(s);
               palette[i*4+3] = 255;
            }
            break;
         }

         case PNG_TYPE('t','R','N','S'): {
            if (first) throw new STBImageException("first not IHDR, cCorrupt PNG");
            if (z.idata) throw new STBImageException("tRNS after IDAT, corrupt PNG");
            if (pal_img_n) {
               if (scan == SCAN_header) { s.img_n = 4; return 1; }
               if (pal_len == 0) throw new STBImageException("tRNS before PLTE, corrupt PNG");
               if (c.length > pal_len) throw new STBImageException("bad tRNS len, corrupt PNG");
               pal_img_n = 4;
               for (i=0; i < c.length; ++i)
                  palette[i*4+3] = get8u(s);
            } else {
               if (!(s.img_n & 1)) throw new STBImageException("tRNS with alpha, corrupt PNG");
               if (c.length != cast(uint) s.img_n*2) throw new STBImageException("bad tRNS len, corrupt PNG");
               has_trans = 1;
               for (k=0; k < s.img_n; ++k)
                  tc[k] = cast(ubyte) get16(s); // non 8-bit images will be larger
            }
            break;
         }

         case PNG_TYPE('I','D','A','T'): {
            if (first) throw new STBImageException("first not IHDR, corrupt PNG");
            if (pal_img_n && !pal_len) throw new STBImageException("no PLTE, corrupt PNG");
            if (scan == SCAN_header) { s.img_n = pal_img_n; return 1; }
            if (ioff + c.length > idata_limit) {
               ubyte *p;
               if (idata_limit == 0) idata_limit = c.length > 4096 ? c.length : 4096;
               while (ioff + c.length > idata_limit)
                  idata_limit *= 2;
               p = cast(ubyte *) realloc(z.idata, idata_limit); if (p == null) throw new STBImageException("outofmem, cOut of memory");
               z.idata = p;
            }
            if (!getn(s, cast(char*)z.idata+ioff,c.length)) throw new STBImageException("outofdata, corrupt PNG");
            ioff += c.length;
            break;
         }

         case PNG_TYPE('I','E','N','D'): {
            uint raw_len;
            if (first) throw new STBImageException("first not IHDR, corrupt PNG");
            if (scan != SCAN_load) return 1;
            if (z.idata == null) throw new STBImageException("no IDAT, corrupt PNG");
            z.expanded = cast(ubyte *) stbi_zlib_decode_malloc_guesssize_headerflag(cast(char *) z.idata, ioff, 16384, cast(int *) &raw_len, !iphone);
            if (z.expanded == null) return 0; // zlib should set error
            free(z.idata); z.idata = null;
            if ((req_comp == s.img_n+1 && req_comp != 3 && !pal_img_n) || has_trans)
               s.img_out_n = s.img_n+1;
            else
               s.img_out_n = s.img_n;
            if (!create_png_image(z, z.expanded, raw_len, s.img_out_n, interlace)) return 0;
            if (has_trans)
               if (!compute_transparency(z, tc, s.img_out_n)) return 0;
            if (iphone && s.img_out_n > 2)
               stbi_de_iphone(z);
            if (pal_img_n) {
               // pal_img_n == 3 or 4
               s.img_n = pal_img_n; // record the actual colors we had
               s.img_out_n = pal_img_n;
               if (req_comp >= 3) s.img_out_n = req_comp;
               if (!expand_palette(z, palette.ptr, pal_len, s.img_out_n))
                  return 0;
            }
            free(z.expanded); z.expanded = null;
            return 1;
         }

         default:
            // if critical, fail
            if (first) throw new STBImageException("first not IHDR, corrupt PNG");
            if ((c.type & (1 << 29)) == 0) {

               throw new STBImageException("PNG not supported: unknown chunk type");
            }
            skip(s, c.length);
            break;
      }
      // end of chunk, read and skip CRC
      get32(s);
   }
}

char *do_png(png *p, int *x, int *y, int *n, int req_comp)
{
   char *result=null;
   if (req_comp < 0 || req_comp > 4) 
      throw new STBImageException("Internal error: bad req_comp");
   if (parse_png_file(p, SCAN_load, req_comp)) {
      result = cast(char*)p.out_;
      p.out_ = null;
      if (req_comp && req_comp != p.s.img_out_n) {
         result = cast(char*)convert_format(cast(ubyte*)result, p.s.img_out_n, req_comp, p.s.img_x, p.s.img_y);
         p.s.img_out_n = req_comp;
         if (result == null) return result;
      }
      *x = p.s.img_x;
      *y = p.s.img_y;
      if (n) *n = p.s.img_n;
   }
   free(p.out_);      p.out_    = null;
   free(p.expanded); p.expanded = null;
   free(p.idata);    p.idata    = null;

   return result;
}

char *stbi_png_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   png p;
   p.s = s;
   return do_png(&p, x,y,comp,req_comp);
}

int stbi_png_test(stbi *s)
{
   int r;
   r = check_png_header(s);
   stbi_rewind(s);
   return r;
}

int stbi_png_info_raw(png *p, int *x, int *y, int *comp)
{
   if (!parse_png_file(p, SCAN_header, 0)) {
      stbi_rewind( p.s );
      return 0;
   }
   if (x) *x = p.s.img_x;
   if (y) *y = p.s.img_y;
   if (comp) *comp = p.s.img_n;
   return 1;
}

int      stbi_png_info(stbi *s, int *x, int *y, int *comp)
{
   png p;
   p.s = s;
   return stbi_png_info_raw(&p, x, y, comp);
}

// Microsoft/Windows BMP image

int bmp_test(stbi *s)
{
   int sz;
   if (get8(s) != 'B') return 0;
   if (get8(s) != 'M') return 0;
   get32le(s); // discard filesize
   get16le(s); // discard reserved
   get16le(s); // discard reserved
   get32le(s); // discard data offset
   sz = get32le(s);
   if (sz == 12 || sz == 40 || sz == 56 || sz == 108) return 1;
   return 0;
}

int stbi_bmp_test(stbi *s)
{
   int r = bmp_test(s);
   stbi_rewind(s);
   return r;
}


// returns 0..31 for the highest set bit
int high_bit(uint z)
{
   int n=0;
   if (z == 0) return -1;
   if (z >= 0x10000) n += 16, z >>= 16;
   if (z >= 0x00100) n +=  8, z >>=  8;
   if (z >= 0x00010) n +=  4, z >>=  4;
   if (z >= 0x00004) n +=  2, z >>=  2;
   if (z >= 0x00002) n +=  1, z >>=  1;
   return n;
}

int bitcount(uint a)
{
   a = (a & 0x55555555) + ((a >>  1) & 0x55555555); // max 2
   a = (a & 0x33333333) + ((a >>  2) & 0x33333333); // max 4
   a = (a + (a >> 4)) & 0x0f0f0f0f; // max 8 per 4, now 8 bits
   a = (a + (a >> 8)); // max 16 per 8 bits
   a = (a + (a >> 16)); // max 32 per 8 bits
   return a & 0xff;
}

int shiftsigned(int v, int shift, int bits)
{
   int result;
   int z=0;

   if (shift < 0) v <<= -shift;
   else v >>= shift;
   result = v;

   z = bits;
   while (z < 8) {
      result += v >> z;
      z += bits;
   }
   return result;
}

char *bmp_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   char *out_;
   uint mr=0,mg=0,mb=0,ma=0, fake_a=0;
   char pal[256][4];
   int psize=0,i,j,compress=0,width;
   int bpp, flip_vertically, pad, target, offset, hsz;
   if (get8(s) != 'B' || get8(s) != 'M') throw new STBImageException("not BMP, Corrupt BMP");
   get32le(s); // discard filesize
   get16le(s); // discard reserved
   get16le(s); // discard reserved
   offset = get32le(s);
   hsz = get32le(s);
   if (hsz != 12 && hsz != 40 && hsz != 56 && hsz != 108) throw new STBImageException("unknown BMP, BMP type not supported: unknown");
   if (hsz == 12) {
      s.img_x = get16le(s);
      s.img_y = get16le(s);
   } else {
      s.img_x = get32le(s);
      s.img_y = get32le(s);
   }
   if (get16le(s) != 1) throw new STBImageException("bad BMP");
   bpp = get16le(s);
   if (bpp == 1) throw new STBImageException("monochrome, BMP type not supported: 1-bit");
   flip_vertically = (cast(int) s.img_y) > 0;
   s.img_y = abs(cast(int) s.img_y);
   if (hsz == 12) {
      if (bpp < 24)
         psize = (offset - 14 - 24) / 3;
   } else {
      compress = get32le(s);
      if (compress == 1 || compress == 2) throw new STBImageException("BMP RLE, BMP type not supported: RLE");
      get32le(s); // discard sizeof
      get32le(s); // discard hres
      get32le(s); // discard vres
      get32le(s); // discard colorsused
      get32le(s); // discard max important
      if (hsz == 40 || hsz == 56) {
         if (hsz == 56) {
            get32le(s);
            get32le(s);
            get32le(s);
            get32le(s);
         }
         if (bpp == 16 || bpp == 32) {
            mr = mg = mb = 0;
            if (compress == 0) {
               if (bpp == 32) {
                  mr = 0xffu << 16;
                  mg = 0xffu <<  8;
                  mb = 0xffu <<  0;
                  ma = 0xffu << 24;
                  fake_a = 1; // @TODO: check for cases like alpha value is all 0 and switch it to 255
               } else {
                  mr = 31u << 10;
                  mg = 31u <<  5;
                  mb = 31u <<  0;
               }
            } else if (compress == 3) {
               mr = get32le(s);
               mg = get32le(s);
               mb = get32le(s);
               // not documented, but generated by photoshop and handled by mspaint
               if (mr == mg && mg == mb) {
                  // ?!?!?
                  throw new STBImageException("bad BMP");
               }
            } else
               throw new STBImageException("bad BMP");
         }
      } else {
         assert(hsz == 108);
         mr = get32le(s);
         mg = get32le(s);
         mb = get32le(s);
         ma = get32le(s);
         get32le(s); // discard color space
         for (i=0; i < 12; ++i)
            get32le(s); // discard color space parameters
      }
      if (bpp < 16)
         psize = (offset - 14 - hsz) >> 2;
   }
   s.img_n = ma ? 4 : 3;
   if (req_comp && req_comp >= 3) // we can directly decode 3 or 4
      target = req_comp;
   else
      target = s.img_n; // if they want monochrome, we'll post-convert
   out_ = cast(char *) malloc(target * s.img_x * s.img_y);
   if (!out_) throw new STBImageException("Out of memory");
   if (bpp < 16) {
      int z=0;
      if (psize == 0 || psize > 256) { free(out_); throw new STBImageException("invalid, Corrupt BMP"); }
      for (i=0; i < psize; ++i) {
         pal[i][2] = get8u(s);
         pal[i][1] = get8u(s);
         pal[i][0] = get8u(s);
         if (hsz != 12) get8(s);
         pal[i][3] = 255;
      }
      skip(s, offset - 14 - hsz - psize * (hsz == 12 ? 3 : 4));
      if (bpp == 4) width = (s.img_x + 1) >> 1;
      else if (bpp == 8) width = s.img_x;
      else { free(out_); throw new STBImageException("bad bpp, corrupt BMP"); }
      pad = (-width)&3;
      for (j=0; j < cast(int) s.img_y; ++j) {
         for (i=0; i < cast(int) s.img_x; i += 2) {
            int v=get8(s),v2=0;
            if (bpp == 4) {
               v2 = v & 15;
               v >>= 4;
            }
            out_[z++] = pal[v][0];
            out_[z++] = pal[v][1];
            out_[z++] = pal[v][2];
            if (target == 4) out_[z++] = 255;
            if (i+1 == cast(int) s.img_x) break;
            v = (bpp == 8) ? get8(s) : v2;
            out_[z++] = pal[v][0];
            out_[z++] = pal[v][1];
            out_[z++] = pal[v][2];
            if (target == 4) out_[z++] = 255;
         }
         skip(s, pad);
      }
   } else {
      int rshift=0,gshift=0,bshift=0,ashift=0,rcount=0,gcount=0,bcount=0,acount=0;
      int z = 0;
      int easy=0;
      skip(s, offset - 14 - hsz);
      if (bpp == 24) width = 3 * s.img_x;
      else if (bpp == 16) width = 2*s.img_x;
      else /* bpp = 32 and pad = 0 */ width=0;
      pad = (-width) & 3;
      if (bpp == 24) {
         easy = 1;
      } else if (bpp == 32) {
         if (mb == 0xff && mg == 0xff00 && mr == 0x00ff0000 && ma == 0xff000000)
            easy = 2;
      }
      if (!easy) {
         if (!mr || !mg || !mb) { free(out_); throw new STBImageException("bad masks, corrupt BMP"); }
         // right shift amt to put high bit in position #7
         rshift = high_bit(mr)-7; rcount = bitcount(mr);
         gshift = high_bit(mg)-7; gcount = bitcount(mr);
         bshift = high_bit(mb)-7; bcount = bitcount(mr);
         ashift = high_bit(ma)-7; acount = bitcount(mr);
      }
      for (j=0; j < cast(int) s.img_y; ++j) {
         if (easy) {
            for (i=0; i < cast(int) s.img_x; ++i) {
               int a;
               out_[z+2] = get8u(s);
               out_[z+1] = get8u(s);
               out_[z+0] = get8u(s);
               z += 3;
               a = (easy == 2 ? get8(s) : 255);
               if (target == 4) out_[z++] = cast(ubyte) a;
            }
         } else {
            for (i=0; i < cast(int) s.img_x; ++i) {
               uint v = (bpp == 16 ? get16le(s) : get32le(s));
               int a;
               out_[z++] = cast(ubyte) shiftsigned(v & mr, rshift, rcount);
               out_[z++] = cast(ubyte) shiftsigned(v & mg, gshift, gcount);
               out_[z++] = cast(ubyte) shiftsigned(v & mb, bshift, bcount);
               a = (ma ? shiftsigned(v & ma, ashift, acount) : 255);
               if (target == 4) out_[z++] = cast(ubyte) a; 
            }
         }
         skip(s, pad);
      }
   }
   if (flip_vertically) {
      char t;
      for (j=0; j < cast(int) s.img_y>>1; ++j) {
         char *p1 = out_ +      j     *s.img_x*target;
         char *p2 = out_ + (s.img_y-1-j)*s.img_x*target;
         for (i=0; i < cast(int) s.img_x*target; ++i) {
            t = p1[i], p1[i] = p2[i], p2[i] = t;
         }
      }
   }

   if (req_comp && req_comp != target) {
      out_ = cast(char*) convert_format(cast(ubyte*)out_, target, req_comp, s.img_x, s.img_y);
      if (out_ == null) return out_; // convert_format frees input on failure
   }

   *x = s.img_x;
   *y = s.img_y;
   if (comp) *comp = s.img_n;
   return out_;
}

char *stbi_bmp_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   return bmp_load(s, x,y,comp,req_comp);
}


// Targa Truevision - TGA
// by Jonathan Dummer

int tga_info(stbi *s, int *x, int *y, int *comp)
{
    int tga_w, tga_h, tga_comp;
    int sz;
    get8u(s);                   // discard Offset
    sz = get8u(s);              // color type
    if( sz > 1 ) {
        stbi_rewind(s);
        return 0;      // only RGB or indexed allowed
    }
    sz = get8u(s);              // image type
    // only RGB or grey allowed, +/- RLE
    if ((sz != 1) && (sz != 2) && (sz != 3) && (sz != 9) && (sz != 10) && (sz != 11)) return 0;
    skip(s,9);
    tga_w = get16le(s);
    if( tga_w < 1 ) {
        stbi_rewind(s);
        return 0;   // test width
    }
    tga_h = get16le(s);
    if( tga_h < 1 ) {
        stbi_rewind(s);
        return 0;   // test height
    }
    sz = get8(s);               // bits per pixel
    // only RGB or RGBA or grey allowed
    if ((sz != 8) && (sz != 16) && (sz != 24) && (sz != 32)) {
        stbi_rewind(s);
        return 0;
    }
    tga_comp = sz;
    if (x) *x = tga_w;
    if (y) *y = tga_h;
    if (comp) *comp = tga_comp / 8;
    return 1;                   // seems to have passed everything
}

int stbi_tga_info(stbi *s, int *x, int *y, int *comp)
{
    return tga_info(s, x, y, comp);
}

int tga_test(stbi *s)
{
   int sz;
   get8u(s);      //   discard Offset
   sz = get8u(s);   //   color type
   if ( sz > 1 ) return 0;   //   only RGB or indexed allowed
   sz = get8u(s);   //   image type
   if ( (sz != 1) && (sz != 2) && (sz != 3) && (sz != 9) && (sz != 10) && (sz != 11) ) return 0;   //   only RGB or grey allowed, +/- RLE
   get16(s);      //   discard palette start
   get16(s);      //   discard palette length
   get8(s);         //   discard bits per palette color entry
   get16(s);      //   discard x origin
   get16(s);      //   discard y origin
   if ( get16(s) < 1 ) return 0;      //   test width
   if ( get16(s) < 1 ) return 0;      //   test height
   sz = get8(s);   //   bits per pixel
   if ( (sz != 8) && (sz != 16) && (sz != 24) && (sz != 32) ) return 0;   //   only RGB or RGBA or grey allowed
   return 1;      //   seems to have passed everything
}

int stbi_tga_test(stbi *s)
{
   int res = tga_test(s);
   stbi_rewind(s);
   return res;
}

char *tga_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   //   read in the TGA header stuff
   int tga_offset = get8u(s);
   int tga_indexed = get8u(s);
   int tga_image_type = get8u(s);
   int tga_is_RLE = 0;
   int tga_palette_start = get16le(s);
   int tga_palette_len = get16le(s);
   int tga_palette_bits = get8u(s);
   int tga_x_origin = get16le(s);
   int tga_y_origin = get16le(s);
   int tga_width = get16le(s);
   int tga_height = get16le(s);
   int tga_bits_per_pixel = get8u(s);
   int tga_inverted = get8u(s);
   //   image data
   char *tga_data;
   char *tga_palette = null;
   int i, j;
   char[4] raw_data;
   char[4] trans_data;
   int RLE_count = 0;
   int RLE_repeating = 0;
   int read_next_pixel = 1;

   //   do a tiny bit of precessing
   if ( tga_image_type >= 8 )
   {
      tga_image_type -= 8;
      tga_is_RLE = 1;
   }
   /* int tga_alpha_bits = tga_inverted & 15; */
   tga_inverted = 1 - ((tga_inverted >> 5) & 1);

   //   error check
   if ( //(tga_indexed) ||
      (tga_width < 1) || (tga_height < 1) ||
      (tga_image_type < 1) || (tga_image_type > 3) ||
      ((tga_bits_per_pixel != 8) && (tga_bits_per_pixel != 16) &&
      (tga_bits_per_pixel != 24) && (tga_bits_per_pixel != 32))
      )
   {
      return null; // we don't report this as a bad TGA because we don't even know if it's TGA
   }

   //   If I'm paletted, then I'll use the number of bits from the palette
   if ( tga_indexed )
   {
      tga_bits_per_pixel = tga_palette_bits;
   }

   //   tga info
   *x = tga_width;
   *y = tga_height;
   if ( (req_comp < 1) || (req_comp > 4) )
   {
      //   just use whatever the file was
      req_comp = tga_bits_per_pixel / 8;
      *comp = req_comp;
   } else
   {
      //   force a new number of components
      *comp = tga_bits_per_pixel/8;
   }
   tga_data = cast(char*)malloc( tga_width * tga_height * req_comp );
   if (!tga_data) throw new STBImageException("Out of memory");

   //   skip to the data's starting position (offset usually = 0)
   skip(s, tga_offset );
   //   do I need to load a palette?
   if ( tga_indexed )
   {
      //   any data to skip? (offset usually = 0)
      skip(s, tga_palette_start );
      //   load the palette
      tga_palette = cast(char*)malloc( tga_palette_len * tga_palette_bits / 8 );
      if (!tga_palette) throw new STBImageException("Out of memory");
      if (!getn(s, tga_palette, tga_palette_len * tga_palette_bits / 8 )) {
         free(tga_data);
         free(tga_palette);
         throw new STBImageException("bad palette, Corrupt TGA");
      }
   }
   //   load the data
   trans_data[0] = trans_data[1] = trans_data[2] = trans_data[3] = 0;
   for (i=0; i < tga_width * tga_height; ++i)
   {
      //   if I'm in RLE mode, do I need to get a RLE chunk?
      if ( tga_is_RLE )
      {
         if ( RLE_count == 0 )
         {
            //   yep, get the next byte as a RLE command
            int RLE_cmd = get8u(s);
            RLE_count = 1 + (RLE_cmd & 127);
            RLE_repeating = RLE_cmd >> 7;
            read_next_pixel = 1;
         } else if ( !RLE_repeating )
         {
            read_next_pixel = 1;
         }
      } else
      {
         read_next_pixel = 1;
      }
      //   OK, if I need to read a pixel, do it now
      if ( read_next_pixel )
      {
         //   load however much data we did have
         if ( tga_indexed )
         {
            //   read in 1 byte, then perform the lookup
            int pal_idx = get8u(s);
            if ( pal_idx >= tga_palette_len )
            {
               //   invalid index
               pal_idx = 0;
            }
            pal_idx *= tga_bits_per_pixel / 8;
            for (j = 0; j*8 < tga_bits_per_pixel; ++j)
            {
               raw_data[j] = tga_palette[pal_idx+j];
            }
         } else
         {
            //   read in the data raw
            for (j = 0; j*8 < tga_bits_per_pixel; ++j)
            {
               raw_data[j] = get8u(s);
            }
         }
         //   convert raw to the intermediate format
         switch (tga_bits_per_pixel)
         {
         case 8:
            //   Luminous => RGBA
            trans_data[0] = raw_data[0];
            trans_data[1] = raw_data[0];
            trans_data[2] = raw_data[0];
            trans_data[3] = 255;
            break;
         case 16:
            //   Luminous,Alpha => RGBA
            trans_data[0] = raw_data[0];
            trans_data[1] = raw_data[0];
            trans_data[2] = raw_data[0];
            trans_data[3] = raw_data[1];
            break;
         case 24:
            //   BGR => RGBA
            trans_data[0] = raw_data[2];
            trans_data[1] = raw_data[1];
            trans_data[2] = raw_data[0];
            trans_data[3] = 255;
            break;
         case 32:
            //   BGRA => RGBA
            trans_data[0] = raw_data[2];
            trans_data[1] = raw_data[1];
            trans_data[2] = raw_data[0];
            trans_data[3] = raw_data[3];
            break;
         default:
             break;
         }
         //   clear the reading flag for the next pixel
         read_next_pixel = 0;
      } // end of reading a pixel
      //   convert to final format
      switch (req_comp)
      {
      case 1:
         //   RGBA => Luminance
         tga_data[i*req_comp+0] = compute_y(trans_data[0],trans_data[1],trans_data[2]);
         break;
      case 2:
         //   RGBA => Luminance,Alpha
         tga_data[i*req_comp+0] = compute_y(trans_data[0],trans_data[1],trans_data[2]);
         tga_data[i*req_comp+1] = trans_data[3];
         break;
      case 3:
         //   RGBA => RGB
         tga_data[i*req_comp+0] = trans_data[0];
         tga_data[i*req_comp+1] = trans_data[1];
         tga_data[i*req_comp+2] = trans_data[2];
         break;
      case 4:
         //   RGBA => RGBA
         tga_data[i*req_comp+0] = trans_data[0];
         tga_data[i*req_comp+1] = trans_data[1];
         tga_data[i*req_comp+2] = trans_data[2];
         tga_data[i*req_comp+3] = trans_data[3];
         break;
      default:
          break;
      }
      //   in case we're in RLE mode, keep counting down
      --RLE_count;
   }
   //   do I need to invert the image?
   if ( tga_inverted )
   {
      for (j = 0; j*2 < tga_height; ++j)
      {
         int index1 = j * tga_width * req_comp;
         int index2 = (tga_height - 1 - j) * tga_width * req_comp;
         for (i = tga_width * req_comp; i > 0; --i)
         {
            char temp = tga_data[index1];
            tga_data[index1] = tga_data[index2];
            tga_data[index2] = temp;
            ++index1;
            ++index2;
         }
      }
   }
   //   clear my palette, if I had one
   if ( tga_palette != null )
   {
      free( tga_palette );
   }
   //   the things I do to get rid of an error message, and yet keep
   //   Microsoft's C compilers happy... [8^(
   tga_palette_start = tga_palette_len = tga_palette_bits =
         tga_x_origin = tga_y_origin = 0;
   //   OK, done
   return tga_data;
}

char *stbi_tga_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   return tga_load(s,x,y,comp,req_comp);
}


// *************************************************************************************************
// Photoshop PSD loader -- PD by Thatcher Ulrich, integration by Nicolas Schulz, tweaked by STB

int psd_test(stbi *s)
{
   if (get32(s) != 0x38425053) return 0;   // "8BPS"
   else return 1;
}

int stbi_psd_test(stbi *s)
{
   int r = psd_test(s);
   stbi_rewind(s);
   return r;
}

char *psd_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   int   pixelCount;
   int channelCount, compression;
   int channel, i, count, len;
   int w,h;
   char *out_;

   // Check identifier
   if (get32(s) != 0x38425053)   // "8BPS"
      throw new STBImageException("not PSD, corrupt PSD image");

   // Check file type version.
   if (get16(s) != 1)
      throw new STBImageException("wrong version, unsupported version of PSD image");

   // Skip 6 reserved bytes.
   skip(s, 6 );

   // Read the number of channels (R, G, B, A, etc).
   channelCount = get16(s);
   if (channelCount < 0 || channelCount > 16)
      throw new STBImageException("wrong channel count, unsupported number of channels in PSD image");

   // Read the rows and columns of the image.
   h = get32(s);
   w = get32(s);
   
   // Make sure the depth is 8 bits.
   if (get16(s) != 8)
      throw new STBImageException("unsupported bit depth, PSD bit depth is not 8 bit");

   // Make sure the color mode is RGB.
   // Valid options are:
   //   0: Bitmap
   //   1: Grayscale
   //   2: Indexed color
   //   3: RGB color
   //   4: CMYK color
   //   7: Multichannel
   //   8: Duotone
   //   9: Lab color
   if (get16(s) != 3)
      throw new STBImageException("wrong color format, PSD is not in RGB color format");

   // Skip the Mode Data.  (It's the palette for indexed color; other info for other modes.)
   skip(s,get32(s) );

   // Skip the image resources.  (resolution, pen tool paths, etc)
   skip(s, get32(s) );

   // Skip the reserved data.
   skip(s, get32(s) );

   // Find out if the data is compressed.
   // Known values:
   //   0: no compression
   //   1: RLE compressed
   compression = get16(s);
   if (compression > 1)
      throw new STBImageException("bad compression, PSD has an unknown compression format");

   // Create the destination image.
   out_ = cast(char *) malloc(4 * w*h);
   if (!out_) throw new STBImageException("Out of memory");
   pixelCount = w*h;

   // Initialize the data to zero.
   //memset( out, 0, pixelCount * 4 );
   
   // Finally, the image data.
   if (compression) {
      // RLE as used by .PSD and .TIFF
      // Loop until you get the number of unpacked bytes you are expecting:
      //     Read the next source byte into n.
      //     If n is between 0 and 127 inclusive, copy the next n+1 bytes literally.
      //     Else if n is between -127 and -1 inclusive, copy the next byte -n+1 times.
      //     Else if n is 128, noop.
      // Endloop

      // The RLE-compressed data is preceeded by a 2-byte data count for each row in the data,
      // which we're going to just skip.
      skip(s, h * channelCount * 2 );

      // Read the RLE data by channel.
      for (channel = 0; channel < 4; channel++) {
         ubyte *p;
         
         p = cast(ubyte*)out_+channel;
         if (channel >= channelCount) {
            // Fill this channel with default data.
            for (i = 0; i < pixelCount; i++) *p = (channel == 3 ? 255 : 0), p += 4;
         } else {
            // Read the RLE data.
            count = 0;
            while (count < pixelCount) {
               len = get8(s);
               if (len == 128) {
                  // No-op.
               } else if (len < 128) {
                  // Copy next len+1 bytes literally.
                  len++;
                  count += len;
                  while (len) {
                     *p = get8u(s);
                     p += 4;
                     len--;
                  }
               } else if (len > 128) {
                  ubyte   val;
                  // Next -len+1 bytes in the dest are replicated from next source byte.
                  // (Interpret len as a negative 8-bit int.)
                  len ^= 0x0FF;
                  len += 2;
                  val = get8u(s);
                  count += len;
                  while (len) {
                     *p = val;
                     p += 4;
                     len--;
                  }
               }
            }
         }
      }
      
   } else {
      // We're at the raw image data.  It's each channel in order (Red, Green, Blue, Alpha, ...)
      // where each channel consists of an 8-bit value for each pixel in the image.
      
      // Read the data by channel.
      for (channel = 0; channel < 4; channel++) {
         ubyte *p;
         
         p = cast(ubyte*)out_ + channel;
         if (channel > channelCount) {
            // Fill this channel with default data.
            for (i = 0; i < pixelCount; i++) *p = channel == 3 ? 255 : 0, p += 4;
         } else {
            // Read the data.
            for (i = 0; i < pixelCount; i++)
               *p = get8u(s), p += 4;
         }
      }
   }

   if (req_comp && req_comp != 4) {
      out_ = cast(char*) convert_format(cast(ubyte*)out_, 4, req_comp, w, h);
      if (out_ == null) return out_; // convert_format frees input on failure
   }

   if (comp) *comp = channelCount;
   *y = h;
   *x = w;
   
   return out_;
}

char *stbi_psd_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   return psd_load(s,x,y,comp,req_comp);
}

// *************************************************************************************************
// Softimage PIC loader
// by Tom Seddon
//
// See http://softimage.wiki.softimage.com/index.php/INFO:_PIC_file_format
// See http://ozviz.wasp.uwa.edu.au/~pbourke/dataformats/softimagepic/

int pic_is4(stbi *s,const char *str)
{
   int i;
   for (i=0; i<4; ++i)
      if (get8(s) != cast(char)str[i])
         return 0;

   return 1;
}

int pic_test(stbi *s)
{
   int i;

   if (!pic_is4(s,"\x53\x80\xF6\x34"))
      return 0;

   for(i=0;i<84;++i)
      get8(s);

   if (!pic_is4(s,"PICT"))
      return 0;

   return 1;
}

struct pic_packet_t
{
   char size,type,channel;
}

char *pic_readval(stbi *s, int channel, char *dest)
{
   int mask=0x80, i;

   for (i=0; i<4; ++i, mask>>=1) {
      if (channel & mask) {
         if (at_eof(s)) throw new STBImageException("bad file, PIC file too short");
         dest[i]=get8u(s);
      }
   }

   return dest;
}

void pic_copyval(int channel,char *dest,const char *src)
{
   int mask=0x80,i;

   for (i=0;i<4; ++i, mask>>=1)
      if (channel&mask)
         dest[i]=src[i];
}

char *pic_load2(stbi *s,int width,int height,int *comp, char *result)
{
   int act_comp=0,num_packets=0,y,chained;
   pic_packet_t packets[10];

   // this will (should...) cater for even some bizarre stuff like having data
    // for the same channel in multiple packets.
   do {
      pic_packet_t *packet;

      if (num_packets== packets.sizeof / packets[0].sizeof)
         throw new STBImageException("bad format, too many packets");

      packet = &packets[num_packets++];

      chained = get8(s);
      packet.size    = get8u(s);
      packet.type    = get8u(s);
      packet.channel = get8u(s);

      act_comp |= packet.channel;

      if (at_eof(s))          throw new STBImageException("bad file, file too short (reading packets)");
      if (packet.size != 8)  throw new STBImageException("bad format, packet isn't 8bpp");
   } while (chained);

   *comp = (act_comp & 0x10 ? 4 : 3); // has alpha channel?

   for(y=0; y<height; ++y) {
      int packet_idx;

      for(packet_idx=0; packet_idx < num_packets; ++packet_idx) {
         pic_packet_t *packet = &packets[packet_idx];
         char *dest = result+y*width*4;

         switch (packet.type) {
            default:
               throw new STBImageException("bad format, packet has bad compression type");

            case 0: {//uncompressed
               int x;

               for(x=0;x<width;++x, dest+=4)
                  if (!pic_readval(s,packet.channel,dest))
                     return null;
               break;
            }

            case 1://Pure RLE
               {
                  int left=width, i;

                  while (left>0) {
                     char count;
                     char[4] value;

                     count=get8u(s);
                     if (at_eof(s))   throw new STBImageException("bad file, file too short (pure read count)");

                     if (count > left)
                        count = cast(ubyte) left;

                     if (!pic_readval(s,packet.channel,value.ptr))  return null;

                     for(i=0; i<count; ++i,dest+=4)
                        pic_copyval(packet.channel,dest,value.ptr);
                     left -= count;
                  }
               }
               break;

            case 2: {//Mixed RLE
               int left=width;
               while (left>0) {
                  int count = get8(s), i;
                  if (at_eof(s))  throw new STBImageException("bad file, file too short (mixed read count)");

                  if (count >= 128) { // Repeated
                     char value[4];
                     int i_;

                     if (count==128)
                        count = get16(s);
                     else
                        count -= 127;
                     if (count > left)
                        throw new STBImageException("bad file, scanline overrun");

                     if (!pic_readval(s,packet.channel,value.ptr))
                        return null;

                     for(i_=0;i_<count;++i_, dest += 4)
                        pic_copyval(packet.channel,dest,value.ptr);
                  } else { // Raw
                     ++count;
                     if (count>left) throw new STBImageException("bad file, scanline overrun");

                     for(i=0;i<count;++i, dest+=4)
                        if (!pic_readval(s,packet.channel,dest))
                           return null;
                  }
                  left-=count;
               }
               break;
            }
         }
      }
   }

   return result;
}

char *pic_load(stbi *s,int *px,int *py,int *comp,int req_comp)
{
   char *result;
   int i, x,y;

   for (i=0; i<92; ++i)
      get8(s);

   x = get16(s);
   y = get16(s);
   if (at_eof(s))  throw new STBImageException("bad file, file too short (pic header)");
   if ((1 << 28) / x < y) throw new STBImageException("too large, image too large to decode");

   get32(s); //skip `ratio'
   get16(s); //skip `fields'
   get16(s); //skip `pad'

   // intermediate buffer is RGBA
   result = cast(char *) malloc(x*y*4);
   memset(result, 0xff, x*y*4);

   if (!pic_load2(s,x,y,comp, result)) {
      free(result);
      result=null;
   }
   *px = x;
   *py = y;
   if (req_comp == 0) req_comp = *comp;
   result=cast(char*)convert_format(cast(ubyte*)result,4,req_comp,x,y);

   return result;
}

int stbi_pic_test(stbi *s)
{
   int r = pic_test(s);
   stbi_rewind(s);
   return r;
}

char *stbi_pic_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   return pic_load(s,x,y,comp,req_comp);
}

// *************************************************************************************************
// GIF loader -- public domain by Jean-Marc Lienher -- simplified/shrunk by stb
struct stbi_gif_lzw 
{
   short prefix;
   ubyte first;
   ubyte suffix;
}

struct stbi_gif
{
   int w,h;
   char *out_;                 // output buffer (always 4 components)
   int flags, bgindex, ratio, transparent, eflags;
   ubyte  pal[256][4];
   ubyte lpal[256][4];
   stbi_gif_lzw codes[4096];
   ubyte *color_table;
   int parse, step;
   int lflags;
   int start_x, start_y;
   int max_x, max_y;
   int cur_x, cur_y;
   int line_size;
}

int gif_test(stbi *s)
{
   int sz;
   if (get8(s) != 'G' || get8(s) != 'I' || get8(s) != 'F' || get8(s) != '8') return 0;
   sz = get8(s);
   if (sz != '9' && sz != '7') return 0;
   if (get8(s) != 'a') return 0;
   return 1;
}

int stbi_gif_test(stbi *s)
{
   int r = gif_test(s);
   stbi_rewind(s);
   return r;
}

void stbi_gif_parse_colortable(stbi *s, ubyte pal[256][4], int num_entries, int transp)
{
   int i;
   for (i=0; i < num_entries; ++i) {
      pal[i][2] = get8u(s);
      pal[i][1] = get8u(s);
      pal[i][0] = get8u(s);
      pal[i][3] = transp ? 0 : 255;
   }   
}

int stbi_gif_header(stbi *s, stbi_gif *g, int *comp, int is_info)
{
   ubyte version_;
   if (get8(s) != 'G' || get8(s) != 'I' || get8(s) != 'F' || get8(s) != '8')
      throw new STBImageException("not GIF, corrupt GIF");

   version_ = get8u(s);
   if (version_ != '7' && version_ != '9')    throw new STBImageException("not GIF, corrupt GIF");
   if (get8(s) != 'a')                      throw new STBImageException("not GIF, corrupt GIF");
 
   g.w = get16le(s);
   g.h = get16le(s);
   g.flags = get8(s);
   g.bgindex = get8(s);
   g.ratio = get8(s);
   g.transparent = -1;

   if (comp != null) *comp = 4;  // can't actually tell whether it's 3 or 4 until we parse the comments

   if (is_info) return 1;

   if (g.flags & 0x80)
      stbi_gif_parse_colortable(s,g.pal, 2 << (g.flags & 7), -1);

   return 1;
}

int stbi_gif_info_raw(stbi *s, int *x, int *y, int *comp)
{
   stbi_gif g;   
   if (!stbi_gif_header(s, &g, comp, 1)) {
      stbi_rewind( s );
      return 0;
   }
   if (x) *x = g.w;
   if (y) *y = g.h;
   return 1;
}

void stbi_out_gif_code(stbi_gif *g, ushort code)
{
   ubyte *p;
   ubyte *c;

   // recurse to decode the prefixes, since the linked-list is backwards,
   // and working backwards through an interleaved image would be nasty
   if (g.codes[code].prefix >= 0)
      stbi_out_gif_code(g, g.codes[code].prefix);

   if (g.cur_y >= g.max_y) return;
  
   p = cast(ubyte*)(&g.out_[g.cur_x + g.cur_y]);
   c = &g.color_table[g.codes[code].suffix * 4];

   if (c[3] >= 128) {
      p[0] = c[2];
      p[1] = c[1];
      p[2] = c[0];
      p[3] = c[3];
   }
   g.cur_x += 4;

   if (g.cur_x >= g.max_x) {
      g.cur_x = g.start_x;
      g.cur_y += g.step;

      while (g.cur_y >= g.max_y && g.parse > 0) {
         g.step = (1 << g.parse) * g.line_size;
         g.cur_y = g.start_y + (g.step >> 1);
         --g.parse;
      }
   }
}

ubyte *stbi_process_gif_raster(stbi *s, stbi_gif *g)
{
   ubyte lzw_cs;
   int len, code;
   uint first;
   int codesize, codemask, avail, oldcode, bits, valid_bits, clear;
   stbi_gif_lzw *p;

   lzw_cs = get8u(s);
   clear = 1 << lzw_cs;
   first = 1;
   codesize = lzw_cs + 1;
   codemask = (1 << codesize) - 1;
   bits = 0;
   valid_bits = 0;
   for (code = 0; code < clear; code++) {
      g.codes[code].prefix = -1;
      g.codes[code].first = cast(ubyte) code;
      g.codes[code].suffix = cast(ubyte) code;
   }

   // support no starting clear code
   avail = clear+2;
   oldcode = -1;

   len = 0;
   for(;;) {
      if (valid_bits < codesize) {
         if (len == 0) {
            len = get8(s); // start new block
            if (len == 0) 
               return cast(ubyte*)g.out_;
         }
         --len;
         bits |= cast(int) get8(s) << valid_bits;
         valid_bits += 8;
      } else {
         int code_ = bits & codemask;
         bits >>= codesize;
         valid_bits -= codesize;
         // @OPTIMIZE: is there some way we can accelerate the non-clear path?
         if (code_ == clear) {  // clear code
            codesize = lzw_cs + 1;
            codemask = (1 << codesize) - 1;
            avail = clear + 2;
            oldcode = -1;
            first = 0;
         } else if (code_ == clear + 1) { // end of stream code
            skip(s, len);
            while ((len = get8(s)) > 0)
               skip(s,len);
            return cast(ubyte*)g.out_;
         } else if (code_ <= avail) {
            if (first) throw new STBImageException("no clear code, corrupt GIF");

            if (oldcode >= 0) {
               p = &g.codes[avail++];
               if (avail > 4096)        throw new STBImageException("too many codes, corrupt GIF");
               p.prefix = cast(short) oldcode;
               p.first = g.codes[oldcode].first;
               p.suffix = (code_ == avail) ? p.first : g.codes[code_].first;
            } else if (code_ == avail)
               throw new STBImageException("illegal code in raster, corrupt GIF");

            stbi_out_gif_code(g, cast(ushort) code);

            if ((avail & codemask) == 0 && avail <= 0x0FFF) {
               codesize++;
               codemask = (1 << codesize) - 1;
            }

            oldcode = code_;
         } else {
            throw new STBImageException("illegal code in raster, corrupt GIF");
         }
      } 
   }
}

void stbi_fill_gif_background(stbi_gif *g)
{
   int i;
   ubyte *c = g.pal[g.bgindex].ptr;
   // @OPTIMIZE: write a dword at a time
   for (i = 0; i < g.w * g.h * 4; i += 4) {
      ubyte *p  = cast(ubyte*)&g.out_[i];
      p[0] = c[2];
      p[1] = c[1];
      p[2] = c[0];
      p[3] = c[3];
   }
}

// this function is designed to support animated gifs, although stb_image doesn't support it
ubyte *stbi_gif_load_next(stbi *s, stbi_gif *g, int *comp, int req_comp)
{
   int i;
   ubyte *old_out = null;

   if (g.out_ == null) {
      if (!stbi_gif_header(s, g, comp,0))     return null; // failure_reason set by stbi_gif_header
      g.out_ = cast(char *) malloc(4 * g.w * g.h);
      if (g.out_ == null)                      throw new STBImageException("Out of memory");
      stbi_fill_gif_background(g);
   } else {
      // animated-gif-only path
      if (((g.eflags & 0x1C) >> 2) == 3) {
         old_out = cast(ubyte*)g.out_;
         g.out_ = cast(char *) malloc(4 * g.w * g.h);
         if (g.out_ == null)                   throw new STBImageException("Out of memory");
         memcpy(g.out_, old_out, g.w*g.h*4);
      }
   }
    
   for (;;) {
      switch (get8(s)) {
         case 0x2C: /* Image Descriptor */
         {
            int x, y, w, h;
            ubyte *o;

            x = get16le(s);
            y = get16le(s);
            w = get16le(s);
            h = get16le(s);
            if (((x + w) > (g.w)) || ((y + h) > (g.h)))
               throw new STBImageException("bad Image Descriptor, corrupt GIF");

            g.line_size = g.w * 4;
            g.start_x = x * 4;
            g.start_y = y * g.line_size;
            g.max_x   = g.start_x + w * 4;
            g.max_y   = g.start_y + h * g.line_size;
            g.cur_x   = g.start_x;
            g.cur_y   = g.start_y;

            g.lflags = get8(s);

            if (g.lflags & 0x40) {
               g.step = 8 * g.line_size; // first interlaced spacing
               g.parse = 3;
            } else {
               g.step = g.line_size;
               g.parse = 0;
            }

            if (g.lflags & 0x80) {
               stbi_gif_parse_colortable(s,g.lpal, 2 << (g.lflags & 7), g.eflags & 0x01 ? g.transparent : -1);
               g.color_table = cast(ubyte *) g.lpal;       
            } else if (g.flags & 0x80) {
               for (i=0; i < 256; ++i)  // @OPTIMIZE: reset only the previous transparent
                  g.pal[i][3] = 255; 
               if (g.transparent >= 0 && (g.eflags & 0x01))
                  g.pal[g.transparent][3] = 0;
               g.color_table = cast(ubyte *) g.pal;
            } else
               throw new STBImageException("missing color table, corrupt GIF");
   
            o = stbi_process_gif_raster(s, g);
            if (o == null) return null;

            if (req_comp && req_comp != 4)
               o = convert_format(o, 4, req_comp, g.w, g.h);
            return o;
         }

         case 0x21: // Comment Extension.
         {
            int len;
            if (get8(s) == 0xF9) { // Graphic Control Extension.
               len = get8(s);
               if (len == 4) {
                  g.eflags = get8(s);
                  get16le(s); // delay
                  g.transparent = get8(s);
               } else {
                  skip(s, len);
                  break;
               }
            }
            while ((len = get8(s)) != 0)
               skip(s, len);
            break;
         }

         case 0x3B: // gif stream termination code
            return cast(ubyte *) 1;

         default:
            throw new STBImageException("unknown code, corrupt GIF");
      }
   }
}

char *stbi_gif_load(stbi *s, int *x, int *y, int *comp, int req_comp)
{
   ubyte *u = null;
   stbi_gif g={0};

   u = stbi_gif_load_next(s, &g, comp, req_comp);
   if (u == cast(void *) 1) u = null;  // end of animated gif marker
   if (u) {
      *x = g.w;
      *y = g.h;
   }

   return cast(char*)u;
}

int stbi_gif_info(stbi *s, int *x, int *y, int *comp)
{
   return stbi_gif_info_raw(s,x,y,comp);
}

int stbi_bmp_info(stbi *s, int *x, int *y, int *comp)
{
   int hsz;
   if (get8(s) != 'B' || get8(s) != 'M') {
       stbi_rewind( s );
       return 0;
   }
   skip(s,12);
   hsz = get32le(s);
   if (hsz != 12 && hsz != 40 && hsz != 56 && hsz != 108) {
       stbi_rewind( s );
       return 0;
   }
   if (hsz == 12) {
      *x = get16le(s);
      *y = get16le(s);
   } else {
      *x = get32le(s);
      *y = get32le(s);
   }
   if (get16le(s) != 1) {
       stbi_rewind( s );
       return 0;
   }
   *comp = get16le(s) / 8;
   return 1;
}

int stbi_psd_info(stbi *s, int *x, int *y, int *comp)
{
   int channelCount;
   if (get32(s) != 0x38425053) {
       stbi_rewind( s );
       return 0;
   }
   if (get16(s) != 1) {
       stbi_rewind( s );
       return 0;
   }
   skip(s, 6);
   channelCount = get16(s);
   if (channelCount < 0 || channelCount > 16) {
       stbi_rewind( s );
       return 0;
   }
   *y = get32(s);
   *x = get32(s);
   if (get16(s) != 8) {
       stbi_rewind( s );
       return 0;
   }
   if (get16(s) != 3) {
       stbi_rewind( s );
       return 0;
   }
   *comp = 4;
   return 1;
}

int stbi_pic_info(stbi *s, int *x, int *y, int *comp)
{
   int act_comp=0,num_packets=0,chained;
   pic_packet_t packets[10];

   skip(s, 92);

   *x = get16(s);
   *y = get16(s);
   if (at_eof(s))  return 0;
   if ( (*x) != 0 && (1 << 28) / (*x) < (*y)) {
       stbi_rewind( s );
       return 0;
   }

   skip(s, 8);

   do {
      pic_packet_t *packet;

      if (num_packets==packets.sizeof / packets[0].sizeof)
         return 0;

      packet = &packets[num_packets++];
      chained = get8(s);
      packet.size    = get8u(s);
      packet.type    = get8u(s);
      packet.channel = get8u(s);
      act_comp |= packet.channel;

      if (at_eof(s)) {
          stbi_rewind( s );
          return 0;
      }
      if (packet.size != 8) {
          stbi_rewind( s );
          return 0;
      }
   } while (chained);

   *comp = (act_comp & 0x10 ? 4 : 3);

   return 1;
}

int stbi_info_main(stbi *s, int *x, int *y, int *comp)
{
   if (stbi_jpeg_info(s, x, y, comp))
       return 1;
   if (stbi_png_info(s, x, y, comp))
       return 1;
   if (stbi_gif_info(s, x, y, comp))
       return 1;
   if (stbi_bmp_info(s, x, y, comp))
       return 1;
   if (stbi_psd_info(s, x, y, comp))
       return 1;
   if (stbi_pic_info(s, x, y, comp))
       return 1;

   // test tga last because it's a crappy test!
   if (stbi_tga_info(s, x, y, comp))
       return 1;
   throw new STBImageException("Image not of any known type, or corrupt");
}

int stbi_info_from_memory(const(ubyte) *buffer, int len, int *x, int *y, int *comp)
{
   stbi s;
   start_mem(&s,buffer,len);
   return stbi_info_main(&s,x,y,comp);
}

