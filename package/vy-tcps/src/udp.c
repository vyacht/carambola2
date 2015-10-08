     /* Send Multicast Datagram code example. */

#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#include <unistd.h>

#define MAXBUF 65536
struct in_addr localInterface;
struct sockaddr_in groupSock;

int sd;
char databuf[1024] = "Multicast test message lol!";
int datalen = sizeof(databuf);

#define BUFLEN 512
#define NPACK 10
#define PORT 2000

void diep(char *s)
{
  perror(s);
  exit(1);
}

char * sent[] = {
"$GPGGA,125108,3854.5087,N,07726.4523,W,8,10,2.0,268.8,M,-33.9,M,,*71\r\n",
"$GPGSA,A,3,03,07,08,11,13,16,19,23,24,28,,,3.6,2.0,3.0*3A\r\n",
"$GPGSV,3,1,10,03,41,050,46,07,60,317,49,08,34,315,45,11,35,148,45*71\r\n",
"$GPGSV,3,2,10,13,38,213,45,16,27,068,43,19,72,076,50,23,09,182,37*74\r\n",
"$GPGSV,3,3,10,24,06,166,35,28,09,271,36*7D\r\n",
"$GPGLL,3854.5087,N,07726.4523,W,125108,V,S*5B\r\n",
"$GPZDA,204224.00,13,06,2005,00,00*67\r\n",
};


/*
 * build instructions
 *
 * gcc -o bclient bclient.c
 *
 * Usage:
 * ./bclient <serverport>
 */


int newtry(int argc, char *argv[ ]) {
  int sock, status, buflen, sinlen;
  char buffer[MAXBUF];
  struct sockaddr_in sock_in;
  int yes = 1;
  int port = 0;
  char c;
  char * bcast = NULL;
  int i = 0;

  while ((c = getopt(argc, argv, "p:b:")) != -1) {
    switch(c) {
    case 'b':
      bcast = optarg;
      break;
    case 'p':
      port = atol(optarg);
      break;

    default:
      break;
    }
  }

  sinlen = sizeof(struct sockaddr_in);
  memset(&sock_in, 0, sinlen);
  buflen = MAXBUF;

  sock = socket (PF_INET, SOCK_DGRAM, IPPROTO_UDP);

  sock_in.sin_addr.s_addr = htonl(INADDR_ANY);
  sock_in.sin_port = htons(0);
  sock_in.sin_family = PF_INET;

  status = bind(sock, (struct sockaddr *)&sock_in, sinlen);
  printf("Bind Status = %d\n", status);

  status = setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &yes, sizeof(int) );
  printf("Setsockopt Status = %d\n", status);

  /* -1 = 255.255.255.255 this is a BROADCAST address,
     a local broadcast address could also be used.
     you can comput the local broadcat using NIC address and its NETMASK 
  */ 

  if(bcast != NULL) {
    sock_in.sin_addr.s_addr=inet_addr(bcast); //htonl(-1); /* send message to 255.255.255.255 */
    printf("sendto using %s\n", bcast);
  } else {
    sock_in.sin_addr.s_addr= htonl(-1); /* send message to 255.255.255.255 */
    printf("sendto using 255.255.255.255\n");
  }
  if(port > 0) {
    sock_in.sin_port = htons(port); /* port number */
    printf("sendto using port %d\n", port);
  } else {
    sock_in.sin_port = htons(PORT); /* port number */
  }
  sock_in.sin_family = PF_INET;

  for(i = 0; i < 7; i++) {
    strcpy(buffer, sent[i]);
    buflen = strlen(buffer);
    if(sendto(sock, buffer, buflen, 0, (struct sockaddr *)&sock_in, sinlen) < 0) {
      printf("sendto Status = %s\n", strerror(errno));
    }
  }

  strcpy(buffer, "$INDPT,1.9,0.0*4F\r\n");
  buflen = strlen(buffer);
  status = sendto(sock, buffer, buflen, 0, (struct sockaddr *)&sock_in, sinlen);
  if(sendto(sock, buffer, buflen, 0, (struct sockaddr *)&sock_in, sinlen) < 0) {
    printf("sendto Status = %s\n", strerror(errno));
  }

  shutdown(sock, 2);
  close(sock);
}

int udp_feed(void)
{
  struct sockaddr_in si_me, si_other;
  int s, i, slen=sizeof(si_other);
  char buf[BUFLEN];
    
  if ((s=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP))==-1)
    diep("socket");
    
  memset((char *) &si_me, 0, sizeof(si_me));
  si_me.sin_family = AF_INET;
  si_me.sin_port = htons(PORT);
  si_me.sin_addr.s_addr = htonl(INADDR_ANY);
  if (bind(s, &si_me, sizeof(si_me))==-1)
    diep("bind");

  while(1) {
    strcpy(databuf, "$GPRMC,123614.000,A,5927.117,N,01818.447,E,00.00,252.7,290508,,,A*68\r\n");
    if(sendto(s, databuf, strlen(databuf), 0, &si_me, &slen) < 0)
      diep("sendto");

    strcpy(databuf, "$INDPT,1.9,0.0*4F\r\n");
    if(sendto(s, databuf, strlen(databuf), 0, &si_me, &slen) < 0)
      diep("sendto");

    usleep(1000*1000);
  }

  close(s);
  return 0;
}

int main (int argc, char *argv[ ]) {

  return newtry(argc, argv);

  /* Create a datagram socket on which to send. */
  sd = socket(AF_INET, SOCK_DGRAM, 0);
  if(sd < 0)  {
      perror("Opening datagram socket error");
      exit(1);
  }  else
    printf("Opening the datagram socket...OK.\n");

   

  /* Initialize the group sockaddr structure with a */
  /* group address of 225.1.1.1 and port 5555. */
  memset((char *) &groupSock, 0, sizeof(groupSock));
  groupSock.sin_family = AF_INET;
  groupSock.sin_addr.s_addr = inet_addr("225.1.1.1");
  groupSock.sin_port = htons(5555);
   

  /* Disable loopback so you do not receive your own datagrams.
     {
     char loopch = 0;
     if(setsockopt(sd, IPPROTO_IP, IP_MULTICAST_LOOP, (char *)&loopch, sizeof(loopch)) < 0)
     {
     perror("Setting IP_MULTICAST_LOOP error");
     close(sd);
     exit(1);
     }
     else
     printf("Disabling the loopback...OK.\n");
     }
  */

     

  /* Set local interface for outbound multicast datagrams. */
  /* The IP address specified must be associated with a local, */
  /* multicast capable interface. */

  localInterface.s_addr = inet_addr("192.168.0.179");
  if(setsockopt(sd, IPPROTO_IP, IP_MULTICAST_IF, (char *)&localInterface, sizeof(localInterface)) < 0) {
      perror("Setting local interface error");
      exit(1);
  } else
    printf("Setting the local interface...OK\n");

  /* Send a message to the multicast group specified by the*/
  /* groupSock sockaddr structure. */
  /*int datalen = 1024;*/

  if(sendto(sd, databuf, datalen, 0, (struct sockaddr*)&groupSock, sizeof(groupSock)) < 0)
    {perror("Sending datagram message error");}
  else
    printf("Sending datagram message...OK\n");

  

  /* Try the re-read from the socket if the loopback is not disable
     if(read(sd, databuf, datalen) < 0)
     {
     perror("Reading datagram message error\n");
     close(sd);
     exit(1);
     }
     else
     {
     printf("Reading datagram message from client...OK\n");
     printf("The message is: %s\n", databuf);
     }
 */

  return 0;

}
