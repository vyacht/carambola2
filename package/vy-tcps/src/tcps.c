
/* Sample TCP server */

#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>

static int keepRunning = 1;
static char deviceId[3];

struct t_msg {
  unsigned char bf[255];
  int len;
};

void intHandler(int dummy) {
    keepRunning = 0;
}

static double degtodm(double angle)
/* decimal degrees to GPS-style, degrees first followed by minutes */
{
    double fraction, integer;
    fraction = modf(angle, &integer);
    return floor(angle) * 100 + fraction * 60;
}

void checksum(char * csum, char * buf, uint16_t len) {

  uint32_t n, crc = 0;
  for (n = 1; n < len; n++)
    crc ^= buf[n];
  (void)snprintf(csum, sizeof(csum), "%02X", crc);

}

void addChecksum(const char * s, uint8_t * b, uint32_t * len) {

  char csum[3] = { '0', '0', '0' };
  int l;

  strcpy(&b[0], s);
  l = strlen(s);

  uint32_t n, crc = 0;
  for (n = 1; n < l; n++)
    crc ^= b[n];
  (void)snprintf(csum, sizeof(csum), "%02X", crc);

  b[l++] = '*';
  b[l++] = csum[0];
  b[l++] = csum[1];
  b[l++] = '\r';
  b[l++] = '\n';
  b[l] = 0;

  *len = l;
}

void gen_ROT(uint8_t *b, uint32_t * len) {

  char csum[3] = { '0', '0', '0' };
  int l;

  const char s[] = "$GPROT,12.7,A";

  strcpy(&b[2], s);
  l = strlen(s) + 1 + 2;

  checksum(csum, b, l - 3);
  b[l++] = '*';
  b[l++] = csum[0];
  b[l++] = csum[1];
  b[l++] = '\r';
  b[l++] = '\n';
  b[l] = 0;

  *len = l; 

  b[1] = (uint8_t)(l-2);         // package len
}

void gen_RMC(uint8_t *b, uint32_t * len, double time, float lat, float lon) {

  // $--RMC,hhmmss.ss,A,llll.ll,a,yyyyy.yy,a,x.x,x.x,xxxx,x.x,a,m,*hh<CR><LF>
  // $--RMC,101112.46,A,4405.556,N,12118.398,W,000.0,000.0,230605,0.0,E

  char csum[3] = { '0', '0', '0' };
  int l;

  char s[255];
  sprintf(s, "$%sRMC,%06.2f,A,%09.4f,%c,%010.4f,%c,000.0,000.0,230605,0.0,E",
	  deviceId,
	  time,
	  degtodm(fabs(lat)),
	  ((lat > 0) ? 'N' : 'S'),
	  degtodm(fabs(lon)),
	  ((lon > 0) ? 'E' : 'W'));

  printf("%s\n", s);

 // package type and origin
  //  b[0] = 0x01 | (0 << 5);

  strcpy(&b[0], s);
  l = strlen(s);

  checksum(csum, b, l);
  b[l++] = '*';
  b[l++] = csum[0];
  b[l++] = csum[1];
  b[l++] = '\r';
  b[l++] = '\n';
  b[l] = '0';

  *len = l; 

  // b[1] = (uint8_t)(l-2);         // package len
}


void gen_nmea0183_VWR(uint8_t *b, uint32_t * len, float awa, char d, float aws) {
  // $--VWR,x.x,a,x.x,N,x.x,M,x.x,K*hh
  
  char s[255];
  bzero(s, 255);
  sprintf(s, "$GPVWR,%2.1f,%c,%2.1f,N,,M,,K", awa, d, aws);
  addChecksum(s, b, len);   
}

void gen_nmea0183_RMC(uint8_t *b, uint32_t * len, float lat, float lon) {
  
  char s[255];
  bzero(s, 255);
  sprintf(s, "$GPRMC,%09.4f,%c,%09.4f,%c", 
    degtodm(fabs(lat)),
    ((lat > 0) ? 'N' : 'S'),
    degtodm(fabs(lon)),
    ((lon > 0) ? 'E' : 'W'));
  addChecksum(s, b, len);
}


void setleu32(uint8_t * b, int offset, uint32_t val) {
  b[offset]     = val;
  b[offset + 1] = val >>  8;
  b[offset + 2] = val >> 16;
  b[offset + 3] = val >> 24;
}

/*
2,129026,2,255,8,12,fc,70,76,ff,ff,ff,ff
2,129026,2,255,8,13,fc,ff,ff,f8,a1,ff,ff
2,129026,2,255,8,14,fd,ff,ff,f8,a1,ff,ff
2,127250,2,255,8,14,ff,ff,ff,7f,00,00,fc
3,129029,2,255,43,14,3a,34,ff,ff,ff,ff,ff,ff,ff,ff,ff,ff,ff,7f,ff,ff,ff,ff,ff,ff,ff,7f,ff,ff,ff,ff,ff,ff,ff,7f,00,fc,ff,ff,7f,ff,7f,ff,ff,ff,7f,ff
3,129033,2,255,8,3a,34,ff,ff,ff,ff,ff,7f
3,126992,2,255,8,14,f0,3a,34,ff,ff,ff,ff
6,129539,2,255,8,79,d3,57,00,83,00,ff,7f
*/

void gen(uint8_t *b, uint32_t * buflen, uint8_t pkglen, 
	 uint32_t pgn, uint8_t prio, uint8_t src, uint8_t dest) {

  // package type and origin
  b[0] = 0x02 | (0 << 5);
  b[1] = (uint8_t)pkglen; // package len

  setleu32(b, 2, pgn);
  setleu32(b, 6, 12);

}

void gen_129029(uint8_t *b, uint32_t * buflen) {

  gen(b, buflen, 43, 129029, 2, 0, 0);

  uint8_t sentence[] = {0x14,0x3a,0x34,0xff,0xff,0xff,0xff,0xff,
			0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,
			0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0xff,
			0xff,0xff,0xff,0xff,0xff,0xff,0x7f,0x00,
			0xfc,0xff,0xff,0x7f,0xff,0x7f,0xff,0xff,
			0xff,0x7f,0xff};

  memcpy(&b[10], sentence, 43);

  *buflen = 53;
}

void gen_129539(uint8_t *b, uint32_t * buflen) {

  gen(b, buflen, 8, 129539, 2, 0, 0);

  uint8_t sentence[] = {0x79,0xd3,0x57,0x00,0x83,0x00,0xff,0x7f};

  memcpy(&b[10], sentence, 8);

  *buflen = 18;
}

void gen_129033(uint8_t *b, uint32_t * buflen) {

  gen(b, buflen, 8, 129033, 2, 0, 0);

  uint8_t sentence[] = {0x3a,0x34,0xff,0xff,0xff,0xff,0xff,0x7f};

  memcpy(&b[10], sentence, 8);

  *buflen = 18;
}

void gen_129026(uint8_t *b, uint32_t * buflen) {

  gen(b, buflen, 8, 129026, 2, 0, 0);

  uint8_t sentence[] = {0x12,0xfc,0x70,0x76,0xff,0xff,0xff,0xff};

  memcpy(&b[10], sentence, 8);

  *buflen = 18;
}

void gen_127250(uint8_t *b, uint32_t * buflen) {

  gen(b, buflen, 8, 127250, 2, 0, 0);

  uint8_t sentence[] = {0x14,0xff,0xff,0xff,0x7f,0x00,0x00,0xfc};

  memcpy(&b[10], sentence, 8);

  *buflen = 18;
}

void gen_127251(uint8_t *b, uint32_t * buflen) {

  gen(b, buflen, 8, 127251, 2, 0, 0);

  uint8_t sentence[] = {0xc4,0x20,0x6d,0x00,0x00,0xff,0xff,0xff};

  memcpy(&b[10], sentence, 8);

  *buflen = 18;
}

static int getParity(unsigned int n) {

    int parity = 0;
    while (n)
    {
        parity = !parity;
        n      = n & (n - 1);
    }
    return parity;
}

static void add_seatalk_byte(uint8_t *b, int *offset, uint8_t c, int cmd) {

  /* generally per definition: 
     - even parity bit set (1, high) if count of 1s is odd
     - odd parity bit set (0, low) if count of 1s is even
  
  // 9th bit for command flag is interpreted as parity bit here
     we check for even parity

  // if the command flag is set then that means that parity even bit is set in the data stream
  */

  int parity = getParity(c); // 1 == odd, 0 == even
  int parerr = 0;
  int o = *offset;

  if(!parity) {
    // input char has even parity
    if(cmd) {
      // and the parity error is signaled 
      // which means parity bit is 1
      parerr = 1;
    }
  } else {
    // input has odd parity
    if(!cmd) {
      parerr = 1;
    }
  }

  if(parerr) {
    b[o++] = 0xFF;
    b[o++] = 0x00;
    b[o++] = c;
  } else {
    b[o++] = c;
  }
  
  *offset = o;
}

void add_sentence(uint8_t *b, uint32_t * buflen, uint8_t * sentence, uint32_t sentence_len) {
  int i;
  *buflen = 0;
  for(i = 0; i < sentence_len; i++) {
    // printf("add seatalk %d: %c (%d)\n", i, sentence[i], *buflen);
    add_seatalk_byte(b, buflen, sentence[i], (i == 0));
  }
}

void gen_st_depth(uint8_t *b, uint32_t * buflen) {

  // uint8_t sentence[] = {0xFF, 0x00, 0x00, 0xFF, 0x00, 0xF2, 0xFF, 0x00, 0x64, 0x00, 0x00};
  uint8_t sentence[] = {0x00, 0xF2, 0x64, 0x00, 0x13};
  // memcpy(&b[0], sentence, 11);

  add_sentence(b, buflen, sentence, 5);

  // *buflen = 11;
}

void gen_st_speed(uint8_t *b, uint32_t * buflen) {

  //  uint8_t sentence[] = {0x20, 0xFF, 0x00, 0xF1, 0xA0, 0x00};
  uint8_t sentence[] = {0x20, 0xF1, 0xA0, 0x00};

  add_sentence(b, buflen, sentence, 4);
  //  memcpy(&b[0], sentence, 6);
  // *buflen = 6;
}

void setleu16(uint8_t * bu, uint32_t value, int offset) {
  bu[offset + 0] = value;
  bu[offset + 1] = value >>  8;
}

void gen_st_wind_angel(uint8_t *b, uint32_t * buflen) {
  //  10  01  XX  YY  Apparent Wind Angle: XXYY/2 degrees right of bow 
  uint8_t sentence[] = {0x10, 0xF1, 0x00, 0x00};
  // set value of 90 deg
  setleu16(sentence, (int)(90.0*2.0), 2);
  add_sentence(b, buflen, sentence, 4);
}

void gen_st_wind_speed(uint8_t *b, uint32_t * buflen) {
  // 11  01  XX  0Y  Apparent Wind Speed: (XX & 0x7F) + Y/10 Knots 

  // set value of 7.5 knots
  uint8_t sentence[] = {0x11, 0xF1, 0x07, 0x05};
  
  add_sentence(b, buflen, sentence, 4);
}

void gen_st_trip_milage(uint8_t *b, uint32_t * buflen) {

  /*
    21  02  XX  XX  0X  Trip Mileage: XXXXX/100 nautical miles
  */
  // should be 100 / 100
  uint8_t sentence[] = {0x21, 0xF2, 0x00, 0x06, 0x04};
  add_sentence(b, buflen, sentence, 5);
}

void gen_st_total_milage(uint8_t *b, uint32_t * buflen) {

  /*
    22  02  XX  XX  00  Total Mileage: XXXX/10 nautical miles 
  */

  // should be 100/10
  uint8_t sentence[] = {0x22, 0xF2, 0x64, 0x00, 0x00};
  add_sentence(b, buflen, sentence, 5);
}

void gen_st_water_temp_23(uint8_t *b, uint32_t * buflen) {

  /*
   23  Z1  XX  YY  Water temperature (ST50): XX deg Celsius, YY deg Fahrenheit
                   Flag Z&4: Sensor defective or not connected (Z=4)
                   Corresponding NMEA sentence: MTW
  */
  uint8_t sentence[] = {0x23, 0x01, 0x1F, 0x00};
  add_sentence(b, buflen, sentence, 4);
}

void gen_st_water_temp_27(uint8_t *b, uint32_t * buflen) {
  /*
   27  01  XX  XX  Water temperature: (XXXX-100)/10 deg Celsius
                   Corresponding NMEA sentence: MTW
  */

  uint8_t sentence[] = {0x27, 0x01, 0x40, 0x01};
  add_sentence(b, buflen, sentence, 4);
}

void gen_st_time(uint8_t *b, uint32_t * buflen, int hh, int mm, int ss) {
  /*
   54  T1  RS  HH  GMT-time: HH hours,
                             6 MSBits of RST = minutes = (RS & 0xFC) / 4
                             6 LSBits of RST = seconds =  ST & 0x3F
  */

  uint8_t T1, RS;
  
  T1 = ((ss & 0x0F) << 4) | 0x01;
  RS = ((mm & 0x3f) << 2) | ((ss & 0x30) >> 4);

  uint8_t sentence[] = {0x54, T1, RS, hh};
  add_sentence(b, buflen, sentence, 4);
}

void gen_st_date(uint8_t *b, uint32_t * buflen, int YY, int MM, int DD) {
  /*
   56  M1  DD  YY  Date: YY year, M month, DD day in month
                   Corresponding NMEA sentence: RMC
  */

  uint8_t sentence[] = {0x56, ((MM&0x0F) << 4) | 0x01, DD, YY};
  add_sentence(b, buflen, sentence, 4);
}

void gen_st_lat_lon_raw(uint8_t *b, uint32_t * buflen) {
  /*
   58  Z5  LA XX YY LO QQ RR   LAT/LON
                   LA Degrees LAT, LO Degrees LON
                   minutes LAT = (XX*256+YY) / 1000
                   minutes LON = (QQ*256+RR) / 1000
                   Z&1: South (Z&1 = 0: North)
                   Z&2: East  (Z&2 = 0: West)
                   Raw unfiltered position, for filtered data use commands 50&51
                   Corresponding NMEA sentences: RMC, GAA, GLL
  */

  uint8_t sentence[] = {0x58, 0x25, 0x3c, 0x24, 0x32, 0x18, 0xd1, 0x19};
  add_sentence(b, buflen, sentence, 8);
}

typedef struct tdata_t {
	FILE *fp;
	struct sockaddr_in cliaddr;
	socklen_t clilen;
	int connfd;
} tdata_t;


void *servlet(void *arg)               
{	
	tdata_t * tdata = (tdata_t*)arg;            /* get & convert the data */
	uint32_t len;
	unsigned char msg[255];

	 uint8_t c;

         while(keepRunning)
         {
	   memset(msg, 0, 255);
	   switch(c % 1) {
           case 0: gen_nmea0183_VWR(msg, &len, 67.9, 'L', 12.2); break;
	   default: break;
	   }

	     //gen_ROT(msg, &len);

	   printf("msg len= %d (%s)\n", len, msg);

//		fputs(msg, tdata->fp);                             /* echo it back */
            sendto(tdata->connfd, msg, len, 0, (struct sockaddr *)&(tdata->cliaddr), sizeof(tdata->cliaddr));
	    usleep(1000*500);
	    c++;
	}

	fclose(tdata->fp);                   /* close the client's channel */
	return 0;                           /* terminate the thread */
}

void panic(const char * p) {
	printf("EXIT %s\n", p);
	exit(1);
}

int fillNMEA0138(struct t_msg *msg, int *lines) {

    uint32_t len;
    time_t t;
    float awa = 67.9; 
    float aws = 7.8; 
    int i = 0;

    srand((unsigned) time(&t));

    for(i = 0; i < 1024; i++) {

       float r = (((rand() % 100) - 50)/5.0);
       float s = (((rand() % 100) - 50)/25.0);
       awa += r;
       aws += s;
       gen_nmea0183_VWR(msg[i].bf, &msg[i].len, awa, 'L', aws);
    }

    *lines = 1024;
}


int main3(int count, char *args[])
{
	struct sockaddr_in servaddr;
	int listenfd, port;

	signal(SIGINT, intHandler);

	if ( count != 2 )
	{
		printf("usage: %s <protocol or portnum>\n", args[0]);
		exit(0);
	}

	/*---Get server's IP and standard service connection--*/
	if ( !isdigit(args[1][0]) )
	{
		struct servent *srv = getservbyname(args[1], "tcp");
		if ( srv == NULL )
			panic(args[1]);
		printf("%s: port=%d\n", srv->s_name, ntohs(srv->s_port));
		port = srv->s_port;
	}
	else
		port = htons(atoi(args[1]));

	listenfd=socket(AF_INET,SOCK_STREAM,0);
	if ( listenfd < 0 )
		panic("socket");

	bzero(&servaddr,sizeof(servaddr));
	servaddr.sin_family = AF_INET;
	servaddr.sin_addr.s_addr=htonl(INADDR_ANY);
	servaddr.sin_port=htons(32000);

	if(bind(listenfd,(struct sockaddr *)&servaddr,sizeof(servaddr))) panic("bind");

	if(listen(listenfd, 1024)) panic("listen");



	while (keepRunning)                         /* process all incoming clients */
	{
		pthread_t child;
		tdata_t tdata;

	        tdata.clilen=sizeof(tdata.cliaddr);
		tdata.connfd = accept(listenfd, (struct sockaddr *)&(tdata.cliaddr), &(tdata.clilen));     /* accept connection */
		printf("connected\n");
		tdata.fp = fdopen(tdata.connfd, "r+");           /* convert into FILE* */
		pthread_create(&child, 0, servlet, &tdata);       /* start thread */
		pthread_detach(child);                      /* don't track it */
	}
}

void readSeatalkBindata(struct t_msg *msg, int *lines) {

   FILE * fp;
   char * line = NULL;
   ssize_t read;
   size_t len;
   int i = 0;

       fp = fopen("/home/bo/prg/ttt", "r");
       if (fp == NULL)
           exit(1);

       while ((read = getline(&line, &len, fp)) != -1) {
           printf("Retrieved line of length %zu :\n", read);
           printf("%s", line);
           *lines++;

           memset(msg[*lines].bf, 0, 255);
           len = (strlen(line) - 1)/2;
           char s[3];
           char *ptr;

           for(i = 0; i < len; i++) {
             s[0] = line[i*2];
             s[1] = line[i*2+1];
             s[2] = 0;
             msg[*lines].bf[i] = (unsigned char)strtol(s, &ptr, 16);
             msg[*lines].len = len;
           }
           for(i = 0; i < msg[*lines].len; i++) {
             printf("%02x ", msg[*lines].bf[i]);
           }
           printf("\n");
       }

       fclose(fp);
}

typedef union sockaddr_u {
    struct sockaddr sa;
    struct sockaddr_in sa_in;
#ifdef IPV6_ENABLE
    struct sockaddr_in6 sa_in6;
#endif /* IPV6_ENABLE */
} sockaddr_t;

int senddata(int ssock, uint8_t * bf, uint32_t len) {

	ssize_t status;
	printf("msg len= %d (%s)\n", len, bf); fflush(stdout);
	  
	status = send(ssock, bf, len, 0); //, (struct sockaddr *)&cliaddr, sizeof(cliaddr));

	if(status != len) {
	  if (status > -1) {
	    printf("short write client with %lu bytes\n", status);
	    return 0;
	  } else if (errno == EAGAIN || errno == EINTR) {
	    printf("client errro.\n");
	    return 0;
	  } else if (errno == EBADF)
	    printf("client has vanished.\n");
	  else if (errno == EWOULDBLOCK)
	    printf("client timed out.\n");
	  else
	    printf("client write error\n");

	  (void)shutdown(ssock, SHUT_RDWR);
	  (void)close(ssock);

	  return 1;
	}

	return 0;
}

int main(int argc, char**argv)
{
   int listenfd,connfd;

   sockaddr_t sat;

   sockaddr_t fsin;

   socklen_t clilen;
   pid_t     childpid;
   struct t_msg msg[1024];
   int sin_len = 0;
   int one = 1;
   int port = 32000;
   double ts = 10.0 * 60.0 * 60.0 + 12.0 * 60.0 + 40.46;
   double lastts = ts;
   uint32_t us = 1000*1000;

   strcpy(deviceId, "GP");

   int i, lines = 0;

   fillNMEA0138(msg, &lines);


   listenfd= socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
   sin_len = sizeof(sat.sa_in);

   memset((char *)&sat.sa_in, 0, sin_len);

   bzero(&sat,sizeof(sat));

   sat.sa_in.sin_family = (sa_family_t) AF_INET;
   sat.sa_in.sin_addr.s_addr = htonl(INADDR_ANY);
   sat.sa_in.sin_port = htons(port);

   if (setsockopt(listenfd, SOL_SOCKET, SO_REUSEADDR, (char *)&one,
		  (int)sizeof(one)) == -1) {
     printf("Error: SETSOCKOPT SO_REUSEADDR\n");
     (void)close(listenfd);
     return 1;
   }

   if(bind(listenfd, &sat.sa, sin_len) < 0) {
      printf("bind() failed\n");
      return 1;
   }

   if (listen(listenfd, 1024) == -1) {
     printf("can't listen on port %d\n", port);
     (void)close(listenfd);
     return -1;
   }

   int n= 0;

   signal(SIGINT, intHandler);
   // annoying, send a decent error instead
   signal(SIGPIPE, SIG_IGN);

   while(keepRunning)
   {
      socklen_t alen = (socklen_t) sizeof(fsin);
      /*@+matchanyintegral@*/
      int ssock =
	accept(listenfd, (struct sockaddr *)&fsin, &alen);

      int opts = fcntl(ssock, F_GETFL);
      static struct linger linger = { 1, 60 };
      char *c_ip;

      if (opts >= 0)
	(void)fcntl(ssock, F_SETFL, opts | O_NONBLOCK);

      if (setsockopt(ssock, SOL_SOCKET, SO_LINGER, (char *)&linger,
		     (int)sizeof(struct linger)) == -1) {
	printf("Error: SETSOCKOPT SO_LINGER\n");
	(void)close(ssock);
	return 0;
      } else {
	// could send announcement
	printf("client is connect \n");
      }

      uint8_t c;

      uint32_t len;
      time_t t;
      float awa = 67.9; 
      float aws = 7.8; 
      int msgId = 0;
      
      srand((unsigned) time(&t));

      while(keepRunning) {
            /*
           
	   switch(c % 1) {
	   case 0: gen_st_speed(msg, &len); break;
	   case 1: gen_st_depth(msg, &len); break;
	   case 2: gen_st_wind_speed(msg, &len); break;
	   case 3: gen_st_wind_angel(msg, &len); break;
	   case 4: gen_st_trip_milage(msg, &len); break;
	   case 5: gen_st_total_milage(msg, &len); break;
	   case 6: gen_st_water_temp_23(msg, &len); break;
	   case 7: gen_st_water_temp_27(msg, &len); break;

	   case 0: gen_127251(msg, &len); break;
	   case 1: gen_127250(msg, &len); break;
	   case 2: gen_129026(msg, &len); break;
	   case 3: gen_129029(msg, &len); break;
	   case 4: gen_129033(msg, &len); break;
	   case 5: gen_129539(msg, &len); break;

           // case 0: gen_nmea0183_VWR(msg, &len, 67.9, 'L', 12.2); break;
	   default: break;
	   }
	     */

	     //gen_ROT(msg, &len);


	/*
	float r = (((rand() % 100) - 50)/5.0);
	float s = (((rand() % 100) - 50)/25.0);
	awa += r;
	aws += s;

	gen_nmea0183_VWR(msg[msgId].bf, &msg[msgId].len, awa, 'L', aws);
	*/

	int hh, mm, ss, ms;
	ms = 100.0*(ts - (uint32_t)ts);
	hh = (int)(ts / 3600);
	mm = (ts - hh*3600)/60;
	ss = (ts - hh*3600 - mm*60);

	printf("hh= %d, mm= %d, ss= %d, ms= %d\n", hh, mm, ss, ms);

	double tss = hh*10000 + mm*100 + ss + ms/100.0;
	/*
	strcpy(deviceId, "XX");
	gen_RMC(msg[msgId].bf, &msg[msgId].len, tss, awa, aws);
	*/
	
        gen_st_lat_lon_raw(msg[msgId].bf, &msg[msgId].len);
	if(senddata(ssock, msg[msgId].bf, msg[msgId].len)) break;

	if(lastts + 10 < ts) {

	  gen_st_time(msg[msgId].bf, &msg[msgId].len, hh, mm, ss);
	  if(senddata(ssock, msg[msgId].bf, msg[msgId].len)) break;

	  gen_st_date(msg[msgId].bf, &msg[msgId].len, 15, 6, 23);
	  if(senddata(ssock, msg[msgId].bf, msg[msgId].len)) break;

	  lastts = ts;
	}

	c++;
	n++;
	usleep(us);
	ts += us * 1.0/((double)(1000.0*1000.0));
      }

   }
}

