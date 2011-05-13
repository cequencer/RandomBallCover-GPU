/* This file is part of the Random Ball Cover (RBC) library.
 * (C) Copyright 2010, Lawrence Cayton [lcayton@tuebingen.mpg.de]
 */

#include<stdio.h>
#include<stdlib.h>
#include<cuda.h>
#include<sys/time.h>
#include<math.h>
#include "defs.h"
#include "utils.h"
#include "utilsGPU.h"
#include "rbc.h"
#include "brute.h"
#include "sKernel.h"

#include "kernels.h" //delete

void parseInput(int,char**);
void readData(char*,matrix);
void readDataText(char*,matrix);
void evalNNerror(matrix, matrix, unint*);
void evalKNNerror(matrix,unint*,vorStruct);
void writeNeighbs(char*,char*,intMatrix,matrix);

char *dataFileX, *dataFileQ, *dataFileXtxt, *dataFileQtxt, *outFile, *outFiletxt, *nnFile;
char runBrute=0, runEval=0;
unint n=0, m=0, d=0, numReps=0, deviceNum=0;

int main(int argc, char**argv){
  matrix x, q;
  intMatrix nnsRBC;
  matrix distsRBC;
  struct timeval tvB,tvE;
  cudaError_t cE;
  vorStruct vorS;

  printf("*****************\n");
  printf("RANDOM BALL COVER\n");
  printf("*****************\n");
  
  parseInput(argc,argv);
  
  gettimeofday( &tvB, NULL );
  printf("Using GPU #%d\n",deviceNum); 
  if(cudaSetDevice(deviceNum) != cudaSuccess){ 
    printf("Unable to select device %d.. exiting. \n",deviceNum); 
    exit(1); 
  } 
  
  size_t memFree, memTot;
  cudaMemGetInfo(&memFree, &memTot);
  printf("GPU memory free = %lu/%lu (MB) \n",(unsigned long)memFree/(1024*1024),(unsigned long)memTot/(1024*1024));
  gettimeofday( &tvE, NULL );
  printf(" init time: %6.2f \n", timeDiff( tvB, tvE ) );
  
  //Setup matrices
  initMat( &q, m, d );
  q.mat = (real*)calloc( sizeOfMat(q), sizeof(*(q.mat)) );
  
  
  if( dataFileQtxt )
    readDataText( dataFileQtxt, q );
  else
    readData( dataFileQ, q );

  unint *nrs = (unint*)calloc( PAD(m), sizeof(*nrs));
  

  //Try the alternative method out
  hdMatrix hdx;
  hdx.fp = fopen(dataFileX, "rb");
  if( !hdx.fp ){
    fprintf(stderr,"error opening input file\n");
    exit(1);
  }
  hdx.r = n;
  hdx.c = d;

  printf("[alt]building the rbc..\n");
  gettimeofday( &tvB, NULL );
  //unint ol = (unint)(((double)numReps)*numReps/((double)n));
  buildBigOneShot( hdx, &vorS, numReps, numReps);
  //  buildVorBig( hdx, &vorS, numReps, ol );
  gettimeofday( &tvE, NULL );
  printf( "\t.. build time = %6.4f \n", timeDiff(tvB,tvE) );

  gettimeofday( &tvB, NULL );
  bruteSearch( vorS.r, q,  nrs );
  gettimeofday( &tvE, NULL );
  printf( "\t.. query time for krbc = %6.4f \n", timeDiff(tvB,tvE) );
  
  //EVAL PHASE
  cE = cudaGetLastError();
  if( cE != cudaSuccess ){
    printf("Execution failed; error type: %s \n", cudaGetErrorString(cE) );
  }
  
  if( runEval )
    evalKNNerror(q,nrs,vorS);
  
  destroyVor( &vorS );
  fclose( hdx.fp );

  cudaThreadExit();

  free( nrs );
  free( q.mat );
}


void parseInput(int argc, char **argv){
  int i=1;
  if(argc <= 1){
    printf("\nusage: \n  testRBC -x datafileX -q datafileQ  -n numPts (DB) -m numQueries -d dim -r numReps [-o outFile] [-g GPU num] [-b] [-e]\n\n");
    printf("\tdatafileX    = binary file containing the database\n");
    printf("\tdatafileQ    = binary file containing the queries\n");
    printf("\tnumPts       = size of database\n");
    printf("\tnumQueries   = number of queries\n");
    printf("\tdim          = dimensionality\n");
    printf("\tnumReps      = number of representatives\n");
    printf("\toutFile      = binary output file (optional)\n");
    printf("\tGPU num      = ID # of the GPU to use (optional) for multi-GPU machines\n");
    printf("\n\tuse -b to run brute force in addition the RBC\n");
    printf("\tuse -e to run the evaluation routine (implicitly runs brute force)\n");
    printf("\n\n\tTo input/output data in text format (instead of bin), use the \n\t-X and -Q and -O switches in place of -x and -q and -o (respectively).\n");
    printf("\n\n");
    exit(0);
  }
  
  while(i<argc){
    if(!strcmp(argv[i], "-x"))
      dataFileX = argv[++i];
    else if(!strcmp(argv[i], "-q"))
      dataFileQ = argv[++i];
    else if(!strcmp(argv[i], "-X"))
      dataFileX = argv[++i];
    else if(!strcmp(argv[i], "-Q"))
      dataFileQ = argv[++i];
    else if(!strcmp(argv[i], "-t"))
      nnFile = argv[++i];
    else if(!strcmp(argv[i], "-n"))
      n = atoi(argv[++i]);
    else if(!strcmp(argv[i], "-m"))
      m = atoi(argv[++i]);
    else if(!strcmp(argv[i], "-d"))
      d = atoi(argv[++i]);
    else if(!strcmp(argv[i], "-r"))
      numReps = atoi(argv[++i]);
    else if(!strcmp(argv[i], "-o"))
      outFile = argv[++i];
    else if(!strcmp(argv[i], "-O"))
      outFiletxt = argv[++i];
    else if(!strcmp(argv[i], "-g"))
      deviceNum = atoi(argv[++i]);
    else if(!strcmp(argv[i], "-b"))
      runBrute=1;
    else if(!strcmp(argv[i], "-e"))
      runEval=1;
    else{
      fprintf(stderr,"%s : unrecognized option.. exiting\n",argv[i]);
      exit(1);
    }
    i++;
  }

  if( !n || !m || !d || !numReps  ){
    fprintf(stderr,"more arguments needed.. exiting\n");
    exit(1);
  }
  if( (!dataFileX && !dataFileXtxt) || (!dataFileQ && !dataFileQtxt) ){
    fprintf(stderr,"more arguments needed.. exiting\n");
    exit(1);
  }
  if( (dataFileX && dataFileXtxt) || (dataFileQ && dataFileQtxt) ){
    fprintf(stderr,"you can only give one database file and one query file.. exiting\n");
    exit(1); 
  }
  if(numReps>n){
    fprintf(stderr,"can't have more representatives than points.. exiting\n");
    exit(1);
  }
}


void readData(char *dataFile, matrix x){
  unint i;
  FILE *fp;
  unint numRead;

  fp = fopen(dataFile,"r");
  if(fp==NULL){
    fprintf(stderr,"error opening file.. exiting\n");
    exit(1);
  }
    
  for( i=0; i<x.r; i++ ){ //can't load everything in one fread
                           //because matrix is padded.
    numRead = fread( &x.mat[IDX( i, 0, x.ld )], sizeof(real), x.c, fp );
    if(numRead != x.c){
      fprintf(stderr,"error reading file.. exiting \n");
      exit(1);
    }
  }
  fclose(fp);
}


void readDataText(char *dataFile, matrix x){
  FILE *fp;
  real t;
  int i,j;

  fp = fopen(dataFile,"r");
  if(fp==NULL){
    fprintf(stderr,"error opening file.. exiting\n");
    exit(1);
  }
    
  for(i=0; i<x.r; i++){
    for(j=0; j<x.c; j++){
      if(fscanf(fp,"%f ", &t)==EOF){
	fprintf(stderr,"error reading file.. exiting \n");
	exit(1);
      }
      x.mat[IDX( i, j, x.ld )]=(real)t;
    }
  }
  fclose(fp);
}


//find the error rate of a set of NNs, then print it.
void evalNNerror(matrix x, matrix q, unint *NNs){
  struct timeval tvB, tvE;
  unint i;

  

  printf("\nComputing error rates (this might take a while)\n");
  real *ranges = (real*)calloc(q.pr,sizeof(*ranges));
  for(i=0;i<q.r;i++){
    if(NNs[i]>n) printf("error");
    ranges[i] = distVec(q,x,i,NNs[i]) - 10e-6;
  }

  unint *cnts = (unint*)calloc(q.pr,sizeof(*cnts));
  gettimeofday(&tvB,NULL);
  bruteRangeCount(x,q,ranges,cnts);
  gettimeofday(&tvE,NULL);
  
  long int nc=0;
  for(i=0;i<m;i++){
    nc += cnts[i];
  }
  double mean = ((double)nc)/((double)m);
  double var = 0.0;
  for(i=0;i<m;i++) {
    var += (((double)cnts[i])-mean)*(((double)cnts[i])-mean)/((double)m);
  }
  printf("\tavg rank = %6.4f; std dev = %6.4f \n\n", mean, sqrt(var));
  printf("(range count took %6.4f) \n", timeDiff(tvB, tvE));
  
  if(outFile){
    FILE* fp = fopen(outFile, "a");
    fprintf( fp, "%d %6.5f %6.5f \n", numReps, mean, sqrt(var) );
    fclose(fp);
  }

  free(ranges);
  free(cnts);
}


//evals the error rate of k-nns
void evalKNNerror(matrix q, unint *NNs, vorStruct vorS){
  unint i,j,k;

  unint m = q.r;
  printf("\nComputing error rates (this might take a while)\n");
  
  unint *trueNNs = (unint*)calloc( 32*m, sizeof(*trueNNs) );
  FILE *fp = fopen( nnFile, "r" );
  if( 32*m != fread( trueNNs, sizeof(unint), 32*m, fp ) ){
    printf("error reading NN file \n");
    exit(1);
  }
  fclose( fp );

  unint *ol = (unint*)calloc( q.r, sizeof(*ol) );
  unint *tol = (unint*)calloc( q.r, sizeof(*tol) );  

   //calc overlap
  for(i=0; i<m; i++){
    //get rep:
    unint ri = NNs[i];
    tol[i] = vorS.groupCount[ri];
    for(j=0; j<vorS.groupCount[ri]; j++){
      for(k=0; k<KMAX; k++){
	ol[i] += ( vorS.xMap[ri][j] == trueNNs[IDX(i, k, 32)] );
      }
    }
  }

  long unsigned int nc=0, tnc=0;
  for(i=0;i<m;i++){
    nc += ol[i];
    tnc += tol[i];
  }

  double mean = ((double)nc)/((double)m);
  double var = 0.0;
  for(i=0;i<m;i++) {
    var += (((double)ol[i])-mean)*(((double)ol[i])-mean)/((double)m);
  }
  printf("\tavg overlap = %6.4f/%d; std dev = %6.4f \n", mean, KMAX, sqrt(var));
  
  mean = ((double)tnc)/((double)m);
  var = 0.0;
  for(i=0;i<m;i++) {
    var += (((double)tol[i])-mean)*(((double)tol[i])-mean)/((double)m);
  }
  printf("\tnum dists = %6.4f/%d; std dev = %6.4f \n", mean, KMAX, sqrt(var));
  
  free(tol);
  free(ol);
}


void writeNeighbs(char *file, char *filetxt, intMatrix NNs, matrix dNNs){
  unint i,j;
  
  if( filetxt ) { //write text

    FILE *fp = fopen(filetxt,"w");
    if( !fp ){
      fprintf(stderr, "can't open output file\n");
      return;
    }
    
    for( i=0; i<m; i++ ){
      for( j=0; j<KMAX; j++ )
	fprintf( fp, "%u ", NNs.mat[IDX( i, j, NNs.ld )] );
      fprintf(fp, "\n");
    }
    
    for( i=0; i<m; i++ ){
      for( j=0; j<KMAX; j++ )
	fprintf( fp, "%f ", dNNs.mat[IDX( i, j, dNNs.ld )]); 
      fprintf(fp, "\n");
    }
    fclose(fp);
    
  }

  if( file ){ //write binary

    FILE *fp = fopen(file,"wb");
    if( !fp ){
      fprintf(stderr, "can't open output file\n");
      return;
    }
    
    for( i=0; i<m; i++ )
      fwrite( &NNs.mat[IDX( i, 0, NNs.ld )], sizeof(*NNs.mat), KMAX, fp );
    for( i=0; i<m; i++ )
      fwrite( &dNNs.mat[IDX( i, 0, dNNs.ld )], sizeof(*dNNs.mat), KMAX, fp );
    
    fclose(fp);
  }
}
