C> Example doxygen comment
c Maximum number of real particles on a processor
#define LPM_LPART 50000

c Number of particle equations being solved
#define LPM_LRS 6

#define LPM_JX  1
#define LPM_JY  2
#define LPM_JZ  3
#define LPM_JVX 4
#define LPM_JVY 5
#define LPM_JVZ 6

c Number of real properties for a particle
#define LPM_LRP 6

#define LPM_R_JRHOP 1
#define LPM_R_JDP   2
#define LPM_R_JVOLP 3
#define LPM_R_JUX   4
#define LPM_R_JUY   5
#define LPM_R_JUZ   6

#define LPM_INCLUDE "lib/LPM"
#define LPM_HEADER  "lib/lpm.h"
#include LPM_HEADER

!-----------------------------------------------------------------------
c main code below
!-----------------------------------------------------------------------
      program test
#include LPM_INCLUDE
      include 'mpif.h' 

      real rparam(lpm_nparam) 
 
      call MPI_INIT(ierr) 
      call MPI_COMM_RANK(MPI_COMM_WORLD, nid, ierr) 
      call MPI_COMM_SIZE(MPI_COMM_WORLD, np , ierr)

      rparam(1)  = 1           ! use custom values
      rparam(2)  = 1           ! time integration method
      rparam(3)  = 2           ! polynomial order of mesh
      rparam(4)  = 1           ! use 1 for tracers only
      rparam(5)  = LPM_R_JDP   ! index of filter non-dimensionalization in rprop
      rparam(6)  = 0           ! non-dimensional Gaussian filter width
      rparam(7)  = 0           ! percent decay of Gaussian filter
      rparam(8)  = 0           ! periodic in x (== 0)
      rparam(9)  = 0           ! periodic in y (== 0)
      rparam(10) = 0           ! periodic in z (== 0)
      rparam(11) = 8E-4        ! time step
      rparam(12) = 3           ! problem dimensions
c     rparam(13) = nid            ! future!!
c     rparam(14) = np             ! future!!
c     rparam(15) = MPI_COMM_WORLD ! future!!

      call init_particles(lpm_y,npart)
c     call lpm_io_vtu_read('new99999.vtu',npart)
      call lpm_init      (rparam,lpm_y,npart,0.0)

      ! time loop
      iostep = 100
      nstep  = 1000
      do lpm_cycle=1,1000
         lpm_time = (lpm_cycle-1)*lpm_dt
         call lpm_solve(lpm_time,lpm_y,lpm_ydot)

         if (lpm_nid .eq. 0) then
            write(6,'(A,I6,A,E16.10)') 'STEP: ',lpm_cycle,
     >                               ', TIME: ',lpm_time
         endif
          if(mod(lpm_cycle,iostep) .eq. 0)  call lpm_io_vtu_write('',0)
      enddo

      call MPI_FINALIZE(ierr) 

      end
!-----------------------------------------------------------------------
      subroutine init_particles(y,npart)
#include LPM_INCLUDE

      real      y(*)
      real      ran2
      external  ran2

      npart   = 50       ! particles/rank to distribute
      dp      = 0.0001   ! particle diameter
      rhop    = 3307.327 ! particle density
      rdum    = ran2(-1-nid) ! initialize random number generator

      do i=1,npart
         ! set initial conditions for solution
         j = LPM_LRS*(i-1)
         y(LPM_JX +j) = 0.1 + 0.8*ran2(2)
         y(LPM_JY +j) = 0.7 + 0.2*ran2(2)
         y(LPM_JZ +j) = 0.1 + 0.8*ran2(2)
         y(LPM_JVX+j) = 0.0
         y(LPM_JVY+j) = 0.0
         y(LPM_JVZ+j) = 0.0
      
         ! set some initial particle properties
         lpm_rprop(LPM_R_JRHOP,i) = rhop
         lpm_rprop(LPM_R_JDP  ,i) = dp
         lpm_rprop(LPM_R_JVOLP,i) = pi/6.0*lpm_rprop(LPM_R_JDP,i)**3
      enddo

      return
      end
!-----------------------------------------------------------------------
      subroutine lpm_fun(time_,y,ydot)
#include LPM_INCLUDE

      real time_
      real y(*)
      real ydot(*)

c setup interpolation
c     call lpm_interpolate_setup
c setup interpolation

C interpolate fields
c     call lpm_interpolate_fld(LPM_R_JUX  , vx_e    )
c     call lpm_interpolate_fld(LPM_R_JUY  , vy_e    )
c     call lpm_interpolate_fld(LPM_R_JUZ  , vz_e    )
C interpolate fields

c evaluate ydot
      do i=1,lpm_npart
         ! striding solution y vector
         j = LPM_LRS*(i-1)

         ! fluid viscosity
         rmu   = 1.8E-5

         ! particle mass
         rmass = lpm_rprop(LPM_R_JVOLP,i)*lpm_rprop(LPM_R_JRHOP,i)

         ! Stokes drag force
         rdum  = 18.0*rmu/lpm_rprop(LPM_R_JDP,i)**2
         rdum  = rdum*lpm_rprop(LPM_R_JVOLP,i)
         fqsx  = rdum*(lpm_rprop(LPM_R_JUX,i) - y(LPM_JVX+j))
         fqsy  = rdum*(lpm_rprop(LPM_R_JUY,i) - y(LPM_JVY+j))
         fqsz  = rdum*(lpm_rprop(LPM_R_JUZ,i) - y(LPM_JVZ+j))

         ! Gravity
         fbx  = 0.0
         fby  = -9.8*rmass
         fbz  = 0.0

         ! set ydot for all LPM_SLN number of equations
         ydot(LPM_JX +j) = y(LPM_JVX +j)
         ydot(LPM_JY +j) = y(LPM_JVY +j)
         ydot(LPM_JZ +j) = y(LPM_JVZ +j)
         ydot(LPM_JVX+j) = (fqsx+fbx)/rmass
         ydot(LPM_JVY+j) = (fqsy+fby)/rmass
         ydot(LPM_JVZ+j) = (fqsz+fbz)/rmass
      enddo 
c evaluate ydot

c project fields
c     call lpm_project
c project fields

      return
      end
!-----------------------------------------------------------------------
      FUNCTION ran2(idum)
      INTEGER idum,IM1,IM2,IMM1,IA1,IA2,IQ1,IQ2,IR1,IR2,NTAB,NDIV 
      REAL ran2,AM,EPS,RNMX
      PARAMETER (IM1=2147483563,IM2=2147483399,AM=1./IM1,IMM1=IM1-1,
     $        IA1=40014,IA2=40692,IQ1=53668,IQ2=52774,IR1=12211,
     $        IR2=3791,NTAB=32,NDIV=1+IMM1/NTAB,EPS=1.2e-7,RNMX=1.-EPS)
c Long period (> 2 ! 1018 ) random number generator of L’Ecuyer with 
c Bays-Durham shuffle and added safeguards. Returns a uniform random deviate 
c between 0.0 and 1.0 (exclusive of the endpoint values). 
c Call with idum a negative integer to initialize; thereafter, do not alter 
c idum between successive deviates in a sequence. RNMX should approximate the 
c largest floating value that is less than 1.
      INTEGER idum2,j,k,iv(NTAB),iy
      SAVE iv,iy,idum2
      DATA idum2/123456789/, iv/NTAB*0/, iy/0/
      if (idum.le.0) then 
         idum1=max(-idum,1) 
         idum2=idum1
         do j=NTAB+8,1,-1
            k=idum1/IQ1
            idum1=IA1*(idum1-k*IQ1)-k*IR1 
            if (idum1.lt.0) idum1=idum1+IM1 
            if (j.le.NTAB) iv(j)=idum1
         enddo
         iy=iv(1) 
      endif
      k=idum1/IQ1 
      idum1=IA1*(idum1-k*IQ1)-k*IR1
      if (idum1.lt.0) idum1=idum1+IM1 
      k=idum2/IQ2 
      idum2=IA2*(idum2-k*IQ2)-k*IR2 
      if (idum2.lt.0) idum2=idum2+IM2 
      j=1+iy/NDIV
      iy=iv(j)-idum2
      iv(j)=idum1 
      if(iy.lt.1)iy=iy+IMM1 
      ran2=min(AM*iy,RNMX)
      return
      END
c----------------------------------------------------------------------

