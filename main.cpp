// POKEY Frequencies Calculator 
// by VinsCool
// Based on the code used for the Pitch Calculations in Raster Music Tracker 1.31+

#include "main.h"
using namespace std;

const char* notes[] =
{
	"C-","C#","D-","D#","E-","F-","F#","G-","G#","A-","A#","B-"
};

//arrays of tuning tables to generate...
//
//Distortion A
int tab_64khz_a_pure[64] = { 0 };
int tab_15khz_a_pure[64] = { 0 };
int tab_179mhz_a_pure[64] = { 0 };
int tab_16bit_a_pure[128] = { 0 };
//
//Distortion C
int tab_64khz_c_gritty[64] = { 0 };
int tab_64khz_c_buzzy[64] = { 0 };
int tab_64khz_c_unstable[64] = { 0 };
int tab_15khz_c_buzzy[64] = { 0 };
int tab_179mhz_c_gritty[64] = { 0 };
int tab_179mhz_c_buzzy[64] = { 0 };
int tab_179mhz_c_unstable[64] = { 0 };
int tab_16bit_c_gritty[128] = { 0 };
int tab_16bit_c_buzzy[128] = { 0 };
int tab_16bit_c_unstable[128] = { 0 };
//
//

int i_audf, i_audc, i_audctl, i_ch_index, FREQ_17, machine_region;
double i_tuning, p[2200] = { 0 };	//this should be more than enough for all possible values...

//AUDCTL bits
bool CLOCK_15 = 0;		//0x01
bool HPF_CH24 = 0;		//0x02
bool HPF_CH13 = 0;		//0x04
bool JOIN_34 = 0;		//0x08
bool JOIN_12 = 0;		//0x10
bool CH3_179 = 0;		//0x20
bool CH1_179 = 0;		//0x40
bool POLY9 = 0;			//0x80
//bool TWO_TONE = 0;	//0x8B
bool JOIN_16BIT = 0;	//valid 16-bit mode
bool CLOCK_179 = 0;		//valid 1.79mhz mode
//bool SAWTOOTH = 0;
//bool SAWTOOTH_INVERTED = 0;

bool IS_BUZZY_DIST_C = 0;
bool IS_GRITTY_DIST_C = 0;
bool IS_UNSTABLE_DIST_C = 0;

bool IS_METALLIC_POLY9 = 0;
//bool IS_UNSTABLE_FREQ = 0;

int main()
{
	cout << endl << "POKEY Frequencies Calculator " VERSION " by VinsCool" << endl;
	SEPARATOR;
repeat_tuning_input:	
	cout << endl << "Please input the A-4 tuning first.\nFor example: 440, 432, 439.8, 440.83751645933, 444.895778867913, etc" << endl;
  	while (true) 
  	{
    		cout << "? ";
    		if (!(cin >> i_tuning)) 
    		{
     			if (cin.eof()) 
     			{
        			cout << "End of file reached, exiting." << endl;
        			return 1;
      			} 
      			else 
      			{
        			cin.clear();
        			cin.ignore(numeric_limits<streamsize>::max(), '\n');
       				cout << "Error: Invalid parameter!" << endl;
      			}   
    		} 
    		else break; 
  	}
  	if (i_tuning < 400) 
  	{
  		cout << "Error: Invalid parameter!\n\nPlease input values above 400" << endl;
  		wait(2);
  		SEPARATOR;
  		goto repeat_tuning_input;
  	}
	if (i_tuning > 500) 
  	{
  		cout << "Error: Invalid parameter!\n\nPlease input values below 500" << endl;
  		wait(2);
  		SEPARATOR;
  		goto repeat_tuning_input;
  	}
	SEPARATOR;
repeat_region_input: 
	cout << endl << "Machine region?\n1- PAL\n2- NTSC" << endl;
  	while (true) 
  	{
    		cout << "? ";
    		if (!(cin >> machine_region)) 
    		{
     			if (cin.eof()) 
     			{
        			cout << "End of file reached, exiting." << endl;
        			return 1;
      			} 
      			else 
      			{
        			cin.clear();
        			cin.ignore(numeric_limits<streamsize>::max(), '\n');
       				cout << "Error: Invalid parameter!" << endl;
      			}   
    		} 
    		else break; 
  	}	
	if (machine_region != 1 && machine_region != 2) 
	{ 
		cout << endl << "Error!\nYou must chose between option 1 or option 2 only." << endl; 
  		wait(2);
  		SEPARATOR;		
		goto repeat_region_input; 
	}
	FREQ_17 = (machine_region == 1) ? FREQ_17_PAL : FREQ_17_NTSC;
	SEPARATOR;

	fstream file;
	file.open("output.txt", ios::out);
	// Backup streambuffers of cout
	streambuf* stream_buffer_cout = cout.rdbuf();
	// Get the streambuffer of the file
	streambuf* stream_buffer_file = file.rdbuf();
	cout << fixed;
	cout << setprecision(2);

	// Redirect cout to file
	cout.rdbuf(stream_buffer_file);
	cout << "File generated using POKEY Frequencies Calculator " VERSION << endl;
	cout << endl << "A-4 Tuning = " << i_tuning << " Hz" << endl;
	cout << "Machine region = ";
	if (machine_region == 1) cout << "PAL";
	else cout << "NTSC";
	cout << endl;
	SEPARATOR;
	cout << endl << "Real frequencies generated using the tuning parameter, they will be used for reference...\n" << endl;
	real_freq();
	SEPARATOR;

	// Redirect cout back to screen
	cout.rdbuf(stream_buffer_cout);
	cout << endl << "Generating frequencies using input parameters, please wait..." << endl;

	// Redirect cout to file
	cout.rdbuf(stream_buffer_file);
	for (int d = 0x00; d < 0xE0; d += 0x20)
	{
		if (d == 0x60) continue;	//duplicate of Distortion 2
		i_audc = d;
		int distortion = d >> 4;
		bool IS_POLY9_NOISE = (d == 0x00 || d == 0x80) ? 1 : 0;	//White Noise generators only have useful pitches in Poly9 mode

/*		if (d == 0xC0)	//Distortion C
		{
			for (int c = 0; c < 4; c++)
			{
				i_ch_index = c;
				for (int t = 0; t < 3; t++)
				{
					cout << endl << "Distortion " << distortion;
					switch (c)
					{
					case 0:
						i_audctl = 0x00; cout << ", 64kHz ";
						break;
					case 1:
						i_audctl = 0x01; cout << ", 15kHz ";
						break;
					case 2:
						i_audctl = 0x20; cout << ", 1.79MHz ";
						break;
					case 3:
						i_audctl = 0x28; cout << ", 16-bit ";
						break;
					}
					if (c == 1)
					{
						cout << "Buzzy";
					}
					else
					{
						switch (t)
						{
						case 0:
							cout << "Gritty (Neither MOD3 or MOD5)";
							break;
						case 1:
							cout << "Buzzy (MOD3)";
							break;
						case 2:
							cout << "Unstable Buzzy (MOD5)";
							break;
						}
					}
					cout << endl;
					SEPARATOR;
					if (c == 3) continue;
				//	{
				//		for (int i = 0xFFFF; i >= 0; i--)	//16-bit
				//		{
				//			i_audf = i; generate_freq();
				//		}	
				//	}
				//	else
					{
						if (c == 1)
						{
							for (int i = 0xFF; i >= 0; i--) { i_audf = i; generate_freq(); }	
							t = 3;
						}
						else
						{
							switch (t)
							{
							case 0:	//Gritty
								for (int i = 0xFF; i >= 0; i--)
								{
									i_audf = i;
									int offset = 1;
									if (c == 2) offset = 4;
									if ((i_audf + offset) % 3 == 0 || (i_audf + offset) % 5 == 0) continue;
									generate_freq();
								}
								break;
							case 1:	//Buzzy
								for (int i = 0xFF; i >= 0; i--)
								{
									i_audf = i;
									int offset = 1;
									if (c == 2) offset = 4;
									if ((i_audf + offset) % 3 != 0) continue;
									generate_freq();
								}
								break;
							case 2:	//Unstable
								for (int i = 0xFF; i >= 0; i--)
								{
									i_audf = i;
									int offset = 1;
									if (c == 2) offset = 4;
									if ((i_audf + offset) % 5 != 0) continue;
									generate_freq();
								}
								break;
							}
						}
					}
					SEPARATOR;
				}
			}
		}
		else	//everything else
*/		//{
			for (int c = 0; c < 4; c++)
			{
				i_ch_index = c;
				cout << endl << "Distortion " << uppercase << hex << distortion << dec;
				if (c == 0) { i_audctl = 0x00; cout << ", 64kHz "; }
				if (c == 1) { i_audctl = 0x01; cout << ", 15kHz "; }
				if (c == 2) { i_audctl = 0x20; cout << ", 1.79MHz "; }
				if (c == 3) { i_audctl = 0x28; cout << ", 16-bit "; }
				if (IS_POLY9_NOISE) { cout << "(Poly9)";  i_audctl = i_audctl | 0x80; }
				cout << endl;
				SEPARATOR;
				if (c == 3) for (int i = 0xFFFF; i >= 0; i--) { i_audf = i; generate_freq(); }	//16-bit
				else for (int i = 0xFF; i >= 0; i--) { i_audf = i; generate_freq(); }	//8-bit
				SEPARATOR;
			}
		//}
	}

	cout << endl << "Test!!! Generated Distortion A 64khz table..." << endl;
	SEPARATOR;
	for (int i = 0; i < 64; i++)
	{	
		int note = i + 48;
		double freq = p[note * 12];
		int distortion = 0xA0;
		generate_table(i, freq, distortion, 0, 0, 0);
		if (i % 12 == 0) cout << endl;
		cout << "$" << hex << tab_64khz_a_pure[i] << ",";
	}
	SEPARATOR;

	cout << endl << "Test!!! Generated Distortion A 15khz table..." << endl;
	SEPARATOR;
	for (int i = 0; i < 64; i++)
	{
		int note = i + 24;
		double freq = p[note * 12];
		int distortion = 0xA0;
		generate_table(i, freq, distortion, 1, 0, 0);
		if (i % 12 == 0) cout << endl;
		cout << "$" << hex << tab_15khz_a_pure[i] << ",";
	}
	SEPARATOR;

	cout << endl << "Test!!! Generated Distortion A 1.79mhz table..." << endl;
	SEPARATOR;
	for (int i = 0; i < 64; i++)
	{
		int note = i + 108;
		double freq = p[note * 12];
		int distortion = 0xA0;
		generate_table(i, freq, distortion, 0, 1, 0);
		if (i % 12 == 0) cout << endl;
		cout << "$" << hex << tab_179mhz_a_pure[i] << ",";
	}
	SEPARATOR;

	cout << endl << "Test!!! Generated Distortion A 16-bit table..." << endl;
	SEPARATOR;
	for (int i = 0; i < 128; i++)
	{
		int msb = 0;
		int lsb = 0;

		if (i < 64)
		{
			int note = i + 24;
			double freq = p[note * 12];
			int distortion = 0xA0;
			generate_table(i, freq, distortion, 0, 0, 1);
		}

		if (i < 64) msb = tab_16bit_a_pure[i * 2] >> 8;
		else lsb = tab_16bit_a_pure[((i - 64) * 2)] & 0x00FF;

		if (i < 64 && i % 12 == 0) cout << endl;
		else if (i >= 64 && (i - 4) % 12 == 0) cout << endl;

		if (i == 0) cout << "MSB" << endl;
		if (i == 64) cout << endl << "LSB" << endl;

		cout << "$";
		if (i < 64) cout << hex << msb;
		else cout << hex << lsb;
		cout << ",";

	//	cout << "$" << hex << tab_16bit_a_pure[i] << ",";
	}
	SEPARATOR;

	cout << endl << "Test!!! Generated Distortion C Buzzy 64khz table..." << endl;
	SEPARATOR;
	for (int i = 0; i < 64; i++)
	{	
		IS_BUZZY_DIST_C = 1;
		IS_GRITTY_DIST_C = 0;
		IS_UNSTABLE_DIST_C = 0;
		
		int note = i + 24;
		double freq = p[note * 12];
		int distortion = 0xC0;
		generate_table(i, freq, distortion, 0, 0, 0);
		if (i % 12 == 0) cout << endl;
		cout << "$" << hex << tab_64khz_c_buzzy[i] << ",";
	}
	SEPARATOR;

/////////
	file.close();	//done, save the .txt file

	// Redirect cout back to screen
	cout.rdbuf(stream_buffer_cout);
	SEPARATOR;

	cout << endl << "Done...\n" << endl;
	wait(2);	//2 seconds
	return 0;
}

void wait(int sec)
{
	clock_t count = clock() + sec * CLOCKS_PER_SEC;
	while (clock() < count) {}
}

void real_freq()	//Parts of this code was used in RMT 1.31+
{
	double PITCH = 0;
	double ratio = pow(2.0, 1.0 / 12.0);
	double centnum = 0;
	char n[3];
	for (int i = 0; i < 180; i++)
	{
		double tuning = i_tuning / 64;
		double PITCH = tuning * pow(ratio, i + 3);
		int notenum = (int)round(centnum * 0.01);
		int note = (notenum + 180) % 12;
		int octave = (notenum / 12) - 1;
		n[0] = notes[note][0];
		n[1] = notes[note][1];
		n[2] = 0;
		centnum += 100;
		p[i * 12] = PITCH;
		if (PITCH < 16.1) continue;	//~C-0, lowest pitch allowed
		cout << n << octave << " = " << PITCH << "Hz" << endl;
	}
}

void generate_freq()	//Parts of this code was used in RMT 1.31+
{
	//register variables
	int i = i_ch_index;
	int audctl = i_audctl;
//	int skctl = 0;
	int audf = i_audf;
//	int audf2 = 0;
//	int audf3 = 0;
	int audf16 = i_audf;		//a 16bit number is fed into it directly instead
	int audc = i_audc;
//	int vol = audc & 0x0f;
	int dist = audc & 0xf0;

	int modoffset = 0;

	//variables for pitch calculation
	double PITCH = 0;
	double divisor = 0;
	int coarse_divisor = 0;
//	int basefreq = 0;
//	int unstablefreq = 0;
//	int x = 0;
//	int y = 0;

	IS_BUZZY_DIST_C = 0;
//	IS_GRITTY_DIST_C = 0;
	IS_UNSTABLE_DIST_C = 0;

	IS_METALLIC_POLY9 = 0;

	CLOCK_15 = audctl & 0x01;
	HPF_CH24 = audctl & 0x02;
	HPF_CH13 = audctl & 0x04;
	JOIN_34 = audctl & 0x08;
	JOIN_12 = audctl & 0x10;
	CH3_179 = audctl & 0x20;
	CH1_179 = audctl & 0x40;
	POLY9 = audctl & 0x80;
//	TWO_TONE = (skctl == 0x8B) ? 1 : 0;

	//combined modes for some special output...
	JOIN_16BIT = ((JOIN_12 && CH1_179 && (i == 1 || i == 5)) || (JOIN_34 && CH3_179 && (i == 3 || i == 7))) ? 1 : 0;
	CLOCK_179 = ((CH1_179 && (i == 0 || i == 4)) || (CH3_179 && (i == 2 || i == 6))) ? 1 : 0;
	if (JOIN_16BIT || CLOCK_179) CLOCK_15 = 0;	//override, these 2 take priority over 15khz mode

	/*
	SAWTOOTH = (CH1_179 && CH3_179 && HPF_CH13 && (dist == 0xA0 || dist == 0xE0) && (i == 0 || i == 4)) ? 1 : 0;
	SAWTOOTH_INVERTED = 0;
	
	if (i % 4 == 0)	//only in valid sawtooth channels
	audf3 = g_atarimem[idx[i + 2]];
	*/

	modoffset = 1;
	coarse_divisor = 1;
	divisor = 1;
	int v_modulo = 0;
	bool IS_VALID = 0;

	if (JOIN_16BIT) modoffset = 7; 
	else if (CLOCK_179) modoffset = 4; 
	else coarse_divisor = (CLOCK_15) ? 114 : 28;

	switch (dist)
	{
	case 0x60:	//Duplicate of Distortion 2
	case 0x20:
		divisor = 31;
		v_modulo = 31;
		IS_VALID = ((audf + modoffset) % v_modulo == 0) ? 0 : 1;
		break;

	case 0x40:
/*
VinsCool — Today at 01:07
after a bit of screwing around I found one of the Distortion 4 common divisor
77.5 appears to be the number used for the Smooth Timbres table
VinsCool — Today at 01:46
ok I have spent enough time already for the week end but I think I found the common divisor for the other table
that would be 232.5
*/
		break;

	case 0x00:
	case 0x80:
		divisor = 255.5;	//Metallic Buzzy
		v_modulo = 73;
		if (POLY9)
		{
			if (CLOCK_179 || JOIN_16BIT)
				IS_METALLIC_POLY9 = ((audf + modoffset) % 7 == 0) ? 1 : 0;
			else
				IS_METALLIC_POLY9 = 1;

			if (IS_METALLIC_POLY9) divisor = 36.5;
			IS_VALID = ((audf + modoffset) % v_modulo == 0) ? 0 : 1;
			if (dist == 0x00 && ((audf + modoffset) % 31 == 0)) IS_VALID = 0; 
		}
		break;

	case 0xE0:	//Duplicate of Distortion A
	case 0xA0:
		IS_VALID = 1;
		break;

	case 0xC0:
		divisor = 7.5;		//Gritty
		v_modulo = (CLOCK_15) ? 5 : 15;
		IS_UNSTABLE_DIST_C = ((audf + modoffset) % 5 == 0) ? 1 : 0;
		IS_BUZZY_DIST_C = ((audf + modoffset) % 3 == 0 || CLOCK_15) ? 1 : 0;
		if (IS_UNSTABLE_DIST_C) divisor = 1.5;	//Unstable
		if (IS_BUZZY_DIST_C) divisor = 2.5;	//Buzzy
		IS_VALID = ((audf + modoffset) % v_modulo == 0) ? 0 : 1;
		break;
	}
	if (IS_VALID)
		PITCH = ((FREQ_17 / (coarse_divisor * divisor)) / (audf + modoffset)) / 2;


/*
	switch (dist)
	{
	case 0x60:	//Duplicate of Distortion 2
	case 0x20:	//Poly5 Squareish tones
		if (JOIN_16BIT)		//16-bit 
			PITCH = (((double)FREQ_17 / 31) / (audf16 + 7)) / 2;
		else if (CLOCK_179)	//1.79mhz
			PITCH = (((double)FREQ_17 / 31) / (audf + 4)) / 2;
		else if (CLOCK_15)	//15khz
			PITCH = (((double)FREQ_17 / 3534) / (audf + 1)) / 2;
		else				//64khz
			PITCH = (((double)FREQ_17 / 868) / (audf + 1)) / 2;
		break;

	case 0x40:	//Poly4+5 distortion
		goto case_default;	//did not find the formula yet
		break;

	case 0x00:	//Poly5+17 white noise 
	case 0x80:	//Poly17 white noise
		if (!POLY9) goto case_default;
		else	//POLY9 is active
		{
			if (JOIN_16BIT)	//16-bit
				goto case_default;	//did not find the formula yet
			else if (CLOCK_179)	//1.79mhz
			{
				basefreq = 255;
				for (int n = 0; n < 37; n++)
				{
					x++;
					y = 7;
					basefreq = basefreq - y;
					if (basefreq == audf)
					{
						PITCH = (((double)FREQ_17 / 36.5) / (audf + 4)) / 2;	//1.79mhz Metallic
						IS_METALLIC_POLY9 = 1;
						break;
					}
					else
					{
						PITCH = (((double)FREQ_17 / 255.5) / (audf + 4)) / 2;	//1.79mhz Metallic Buzzy
						IS_METALLIC_POLY9 = 0;
					}
				}
			}
			else if (CLOCK_15)	//15khz
				goto case_default;	//did not find the formula yet
			else
			{
				PITCH = (((double)FREQ_17 / 1022) / (audf + 1)) / 2;	//64khz Metallic
				IS_METALLIC_POLY9 = 1;
			}
		}
		break;
	case 0xE0:	//Duplicate of Distortion A
	case 0xA0:	//Pure tones
		if (JOIN_16BIT)	//16-bit
			PITCH = (((double)FREQ_17) / (audf16 + 7)) / 2;
//*
		else if (SAWTOOTH)
		{
			if (audf == audf3) goto do_179mhz;	//failsafe
			int delta = (audf > audf3) ? (audf - audf3) : (audf3 - audf);
			if (audf > audf3) SAWTOOTH_INVERTED = 1;
			PITCH = ((((double)FREQ_17) / (audf + 4)) / (audf3 + 4)) * delta;
		}	
do_179mhz:
//
		else if (CLOCK_179)	//1.79mhz
			PITCH = (((double)FREQ_17) / (audf + 4)) / 2;
		else if (CLOCK_15)	//15khz
			PITCH = (((double)FREQ_17 / 114) / (audf + 1)) / 2;
		else				//64khz
			PITCH = (((double)FREQ_17 / 28) / (audf + 1)) / 2;
		break;

	case 0xC0:	//Poly4 bass tones
		if (JOIN_16BIT)	//16-bit
		{
			dividend = 7.5;		//16-bit Gritty
			if ((audf + 7) % 15 == 0) goto case_default;	//silence
			if ((audf + 7) % 5 == 0)
			{
				dividend = 1.5;	//16-bit MOD5 Buzzy (unstable!)
				IS_BUZZY_DIST_C = 1;
				IS_UNSTABLE_FREQ = 1;
			}
			if ((audf + 7) % 3 == 0)
			{
				dividend = 2.5;	//16-bit Buzzy
				IS_BUZZY_DIST_C = 1;
			}
			PITCH = ((FREQ_17 / dividend) / (audf16 + 7)) / 2;	
		}
		else if (CLOCK_179)	//1.79mhz
		{
			dividend = 7.5;		//1.79mhz Gritty
			if ((audf + 4) % 15 == 0) goto case_default;	//silence
			if ((audf + 4) % 5 == 0)
			{
				dividend = 1.5;	//1.79mhz MOD5 Buzzy (unstable!)
				IS_BUZZY_DIST_C = 1;
				IS_UNSTABLE_FREQ = 1;
			}
			if ((audf + 4) % 3 == 0)
			{
				dividend = 2.5;	//1.79mhz Buzzy
				IS_BUZZY_DIST_C = 1;
			}
			PITCH = (((double)FREQ_17 / dividend) / (audf + 4)) / 2;
		}
		else if (CLOCK_15)	//15khz
		{
			dividend = 285;		//15khz Buzzy
			if ((audf + 1) % 5 == 0) goto case_default;	//silence
			PITCH = (((double)FREQ_17 / dividend) / (audf + 1)) / 2;
			IS_BUZZY_DIST_C = 1;
		}
		else	//64khz
		{	
			dividend = 210;		//64khz Gritty
			if ((audf + 1) % 15 == 0) goto case_default;	//silence
			if ((audf + 1) % 5 == 0)
			{
				dividend = 42;	//64khz MOD5 Buzzy (unstable!)
				IS_BUZZY_DIST_C = 1;
				IS_UNSTABLE_FREQ = 1;
			}
			if ((audf + 1) % 3 == 0)
			{
				dividend = 70;	//64khz Buzzy
				IS_BUZZY_DIST_C = 1;
			}
			PITCH = (((double)FREQ_17 / dividend) / (audf + 1)) / 2;
		}
		break;

case_default:
	default:
		PITCH = '\0';	//0.00
		break;
	}
*/


	if (PITCH > 16.1)	//~C-0, lowest pitch allowed
	{
		char n[3];
		double tuning = i_tuning;
		double centnum = 1200 * log2(PITCH / tuning);
		int notenum = (int)round(centnum * 0.01) + 72;
		int note = ((notenum + 96) - 3) % 12;
		int octave = ((notenum - 3) / 12) - 1;
		double cents = (centnum - (notenum - 72) * 100);
		double reference = p[(notenum - 3) * 12];
		n[0] = notes[note][0];
		n[1] = notes[note][1];
		n[2] = 0;
		cout << endl << hex << "AUDF = " << i_audf;

		if (dist == 0x00 || dist == 0x80)
		{
			cout << " (";
			if (IS_METALLIC_POLY9) cout << "Metallic";
			else cout << "Fuzzy";
			cout << ")";
		}

		if (dist == 0xC0)
		{
			cout << " (";
			if (IS_UNSTABLE_DIST_C) cout << "Unstable";
			else if (IS_BUZZY_DIST_C) cout << "Buzzy";
			else cout << "Gritty";
			cout << ")";
		}

		cout << endl << "Note = " << n << dec << octave << " (";
		if (cents >= 0) cout << "+";
		cout << cents << " cents off), " << PITCH << "Hz" << endl;
		cout << "Theoretical = " << reference << "Hz" << endl;
	}
}

void generate_table(int note, double freq, int distortion, bool CLOCK_15, bool CLOCK_179, bool JOIN_16BIT)
{
	int audf = 0;
	int modoffset = 1;
	int coarse_divisor = 1;
	int v_modulo = 0;
	double divisor = 1;
	double PITCH = 0;
	bool IS_VALID = 0;

	if (JOIN_16BIT) modoffset = 7;
	else if (CLOCK_179) modoffset = 4;
	else coarse_divisor = (CLOCK_15) ? 114 : 28;

	switch (distortion)
	{
	case 0xA0:
		audf = (int)round(((FREQ_17 / (coarse_divisor * divisor)) / (2 * freq)) - modoffset);
		if (!JOIN_16BIT && (audf > 0xFF || audf < 0x00)) break;	//invalid 8-bit range!
		if (JOIN_16BIT) tab_16bit_a_pure[note * 2] = audf;
		else if (CLOCK_179) tab_179mhz_a_pure[note] = audf;
		else if (CLOCK_15) tab_15khz_a_pure[note] = audf;
		else tab_64khz_a_pure[note] = audf; 
		break;

	case 0xC0:
		divisor = (IS_BUZZY_DIST_C || CLOCK_15) ? 2.5 : 7.5;
		v_modulo = (CLOCK_15) ? 5 : 15;
		if (IS_UNSTABLE_DIST_C) divisor = 1.5;
		audf = (int)round(((FREQ_17 / (coarse_divisor * divisor)) / (2 * freq)) - modoffset);

		if (IS_BUZZY_DIST_C)	//verify MOD3 integrity
		{
			if ((audf + modoffset) % 3 == 0 && (audf + modoffset) % 5 != 0) goto process_dist_c_tab;	//all good!
			
			int tmp_audf_up = audf;		//begin from the currently invalid audf
			int tmp_audf_down = audf;	
			double tmp_freq_up = 0;
			double tmp_freq_down = 0;
			
			for (int o = 0; o < 6; o++)	//get the closest compromise up and down first
			{
				if ((tmp_audf_up + modoffset) % 3 != 0 || (tmp_audf_up + modoffset) % 5 == 0) tmp_audf_up++;
				if ((tmp_audf_down + modoffset) % 3 != 0 || (tmp_audf_down + modoffset) % 5 == 0) tmp_audf_down--;
			}
			
			PITCH = ((FREQ_17 / (coarse_divisor * divisor)) / (tmp_audf_up + modoffset)) / 2;
			tmp_freq_up = freq - PITCH;	//first delta, up
			
			PITCH = ((FREQ_17 / (coarse_divisor * divisor)) / (tmp_audf_down + modoffset)) / 2;
			tmp_freq_down = PITCH - freq;	//second delta, down
			
			PITCH = tmp_freq_down - tmp_freq_up;
			
			if (PITCH > 0) audf = tmp_audf_up; //positive, meaning delta up is closer than delta down
			else audf = tmp_audf_down; //negative, meaning delta down is closer than delta up

		}
		
process_dist_c_tab: 
		if (!JOIN_16BIT && (audf > 0xFF || audf < 0x00)) break;	//invalid 8-bit range!
//		if (JOIN_16BIT) tab_16bit_a_pure[note * 2] = audf;
//		else if (CLOCK_179) tab_179mhz_a_pure[note] = audf;
//		else if (CLOCK_15) tab_15khz_a_pure[note] = audf;
//		else tab_64khz_c_buzzy[note] = audf; 

		if (IS_BUZZY_DIST_C) tab_64khz_c_buzzy[note] = audf; 
		break;		
		
	}



	//PITCH = ((FREQ_17 / (coarse_divisor * divisor)) / (audf + modoffset)) / 2;
	//=ROUND(( ($B$2/28) /(2*$J45))-1)+$AE45
}

