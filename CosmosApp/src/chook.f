      module modControl
!     intID: coll/decay counter. Primary interaction is 1.
!     stampLeft/stampNext: products still to be numbered.
!     cmovePtcl copies one track onto every child, so the
!     per-child index is written in cpush, not in cosmosX.
!     freecFixed: first hadronic collision releases FreeCcopy,
!     or later collisions stay pinned to the injection point.
      integer, save :: intID = 0
      integer, save :: stampLeft = 0
      integer, save :: stampNext = 1
      logical, save :: freecFixed = .false.
      end module modControl

#include "cmain.f"

!  *************************************** hook for Beginning of a Run
      subroutine chookBgRun
      implicit none
#include "Zmanagerp.h"

      call cwriteParam(ErrorOut, 0)
      call cprintPrim(ErrorOut)
      call cprintObs(ErrorOut)
      end


!     *********************************** hook for Beginning of  1 event
      subroutine chookBgEvent
      use modControl
      use chook_hdf5
      use modCodeConv
      implicit none
#include "Ztrack.h"
#include "Zevhnp.h"
#include "Zobs.h"
#include "Zobsv.h"

      type(coord):: angle
      type(track):: incident
      integer remain, pdg, iev, icum, i
      real(8):: cz, zenith
      real(8):: hplanes(maxNoOfSites)

      intID = 0
      stampLeft = 0
      stampNext = 1
      freecFixed = .false.

!     Primary is already stacked. Clear its interaction lineage.
      call cpop(incident, remain)
      if(remain .gt. 0) then
         incident%user_i1 = 0
         incident%user_i2 = 0
         incident%user_i3 = 0
         incident%user_i4 = 0
         incident%user_i5 = 0
         call cpush(incident)
      endif

      call cqIncident(incident, angle)
      call ccos2pdg(incident%p, pdg)
      call cqEventNo(iev, icum)

      cz = incident%vec%coszenith
      if(cz .gt. 1.d0) cz = 1.d0
      if(cz .lt. -1.d0) cz = -1.d0
      zenith = acos(cz)*180.d0/acos(-1.d0)

      do i = 1, NoOfSites
         hplanes(i) = ObsSites(i)%pos%height
      enddo

      call shower_h5_begin(icum, pdg, incident%p%fm%p(4),
     *     incident%p%fm%p(1), incident%p%fm%p(2),
     *     incident%p%fm%p(3), zenith, IntModel,
     *     incident%pos%height, NoOfSites, hplanes(1:NoOfSites))
      end


!     ************************************ hook for observation
      subroutine chookObs(aTrack, id)
      use chook_hdf5
      use modCodeConv
      implicit none
#include "Ztrack.h"
      integer id
      type(track):: aTrack
      integer pdg
      real(8):: pabs, px, py, pz

!     id = 2: the particle crossed an observation plane.
      if(id .ne. 2) return

      call ccos2pdg(aTrack%p, pdg)
      pabs = sqrt(aTrack%p%fm%p(1)**2 + aTrack%p%fm%p(2)**2
     *     + aTrack%p%fm%p(3)**2)
!     Direction is in the detector frame. Momentum follows it.
      px = aTrack%vec%w%r(1)*pabs
      py = aTrack%vec%w%r(2)*pabs
      pz = aTrack%vec%w%r(3)*pabs
      call shower_h5_observe(int(aTrack%where), pdg,
     *     aTrack%p%fm%p(4), px, py, pz,
     *     aTrack%pos%xyz%r(1), aTrack%pos%xyz%r(2),
     *     aTrack%user_i1, aTrack%user_i5)
      end

!    *********************************** hook for end of 1 event
      subroutine chookEnEvent
      use chook_hdf5
      implicit none
      call shower_h5_end
      end


!     ********************************* hook for end of a run
      subroutine chookEnRun
      implicit none
      end

!     ********************************* hook for trace
      subroutine chookTrace
      implicit none
      end

!     ********************* electron interaction hook
      subroutine chookEInt(never)
      implicit none
      integer never
      never = 1
      end

!     ********************* gamma interaction hook
      subroutine chookGInt(never)
      implicit none
      integer never
      never = 1
      end

!     ********************* non e-g particle interaction hook
!     Counts coll and decay. Electromagnetic processes are ignored.
      subroutine chookNEPInt(never)
      use chook_hdf5
      use modSetIntInf
      use modControl
      use modCodeConv
      use modColInfo, only: ColA => TargetNucleonNo,
     *     ColZ => TargetProtonNo
      implicit none

#include  "Ztrack.h"
#include  "Ztrackp.h"
#include  "Ztrackv.h"
#include  "Zpwork.h"

      integer never
      type(track):: aTrack
      character(len=8):: proc
      integer i, ppdg, spdg, ta, tz, tpdg
      integer ncoll, ndecay, parentInt, parentSec
      real(8):: pabs, ux, uy, uz, parallel, eproj
      real(8):: spx, spy, spz, pt
      integer, allocatable:: sec_pdg(:)
      real(8), allocatable:: sec_e(:), sec_px(:), sec_py(:)
      real(8), allocatable:: sec_pz(:), sec_x(:), sec_pt(:)

      never = 0
      proc = IntInfArray(ProcessNo)%process
      if(proc .ne. 'coll' .and. proc .ne. 'decay') return

      intID = intID + 1
      if(proc .eq. 'coll' .and. .not. freecFixed) then
         FreeCcopy = .true.
         freecFixed = .true.
      endif

!     Projectile arrives as MovedTrack. Counts are those of the
!     coll/decay that created it, including that interaction.
      aTrack = MovedTrack
      parentInt = aTrack%user_i1
      parentSec = aTrack%user_i5
      ncoll = aTrack%user_i2
      ndecay = aTrack%user_i3
      if(proc .eq. 'coll') then
         ncoll = ncoll + 1
      else
         ndecay = ndecay + 1
      endif

      call ccos2pdg(aTrack%p, ppdg)
      if(proc .eq. 'coll' .and. ColA .gt. 0
     *     .and. ColZ .gt. 0) then
         ta = ColA
         tz = ColZ
         tpdg = 1000000000 + tz*10000 + ta*10
      else
         ta = 0
         tz = 0
         tpdg = 0
      endif

      pabs = sqrt(aTrack%p%fm%p(1)**2
     *     + aTrack%p%fm%p(2)**2
     *     + aTrack%p%fm%p(3)**2)
      if(pabs .gt. 0.d0) then
         ux = aTrack%p%fm%p(1)/pabs
         uy = aTrack%p%fm%p(2)/pabs
         uz = aTrack%p%fm%p(3)/pabs
      else
         ux = aTrack%vec%w%r(1)
         uy = aTrack%vec%w%r(2)
         uz = aTrack%vec%w%r(3)
      endif
      eproj = aTrack%p%fm%p(4)

      allocate(sec_pdg(Nproduced), sec_e(Nproduced))
      allocate(sec_px(Nproduced), sec_py(Nproduced))
      allocate(sec_pz(Nproduced), sec_x(Nproduced))
      allocate(sec_pt(Nproduced))

      do i = 1, Nproduced
         call ccos2pdg(Pwork(i), spdg)
         sec_pdg(i) = spdg
         sec_e(i) = Pwork(i)%fm%p(4)
         spx = Pwork(i)%fm%p(1)
         spy = Pwork(i)%fm%p(2)
         spz = Pwork(i)%fm%p(3)
         sec_px(i) = spx
         sec_py(i) = spy
         sec_pz(i) = spz
         if(eproj .gt. 0.d0) then
            sec_x(i) = sec_e(i)/eproj
         else
            sec_x(i) = 0.d0
         endif
         parallel = spx*ux + spy*uy + spz*uz
         pt = (spx - parallel*ux)**2
     *      + (spy - parallel*uy)**2
     *      + (spz - parallel*uz)**2
         if(pt .gt. 0.d0) then
            sec_pt(i) = sqrt(pt)
         else
            sec_pt(i) = 0.d0
         endif
      enddo

      call shower_h5_interaction(intID, ppdg, eproj,
     *     aTrack%p%fm%p(1), aTrack%p%fm%p(2),
     *     aTrack%p%fm%p(3), ta, tz, tpdg,
     *     aTrack%pos%height,
     *     aTrack%pos%xyz%r(1), aTrack%pos%xyz%r(2),
     *     aTrack%pos%xyz%r(3), proc, ncoll, ndecay,
     *     parentInt, parentSec, Nproduced, sec_pdg,
     *     sec_e, sec_px, sec_py, sec_pz, sec_x, sec_pt)

!     Children inherit this interaction via cmovePtcl's copy.
!     Their own product index is attached in cpush.
      aTrack%user_i1 = intID
      aTrack%user_i2 = ncoll
      aTrack%user_i3 = ndecay
      MovedTrack = aTrack
      stampNext = 1
      stampLeft = Nproduced
      end

!     Number products of the coll/decay that just returned.
!     The library cpush is renamed cpshx at link time.
      subroutine cpush(a)
      use modControl
      implicit none
#include "Ztrack.h"
      type(track):: a
      external cpshx
      if(stampLeft .gt. 0) then
         a%user_i5 = stampNext
         stampNext = stampNext + 1
         stampLeft = stampLeft - 1
      endif
      call cpshx(a)
      end
