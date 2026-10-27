!   #ifndef Ztrack_
!   #define Ztrack_
!    structure used when tracking a particle
!    *************************
#include  "Zcondc.h"
#include  "Zptcl.h"
#include  "Zcoord.h"
#include  "Zpos.h"
#include  "Zdirec.h"
#include  "Zmagfield.h"
!     ---------------------
      type track      ! full particle attributes in Cosmos
        sequence

          type(ptcl):: p    ! basic ptcl attributes.

!               position and time
          type(position):: pos
          real*8 t           ! time in length/beta (m)
          type(direc):: vec
          real*4 wgt         ! weight for thin sampling
          integer*2 where    ! current obsSite no. (0 is initial value)
          integer*2 asflag   ! non 0, if As has been generated from this
!                             ptcl (only for electrons)
!         Lineage of the last coll/decay, copied through EM processes.
!         0 means this particle is the primary.
          real*8   user      ! unused
          real*8   user2     ! unused
          real*8   user3     ! unused
          real*8   user4     ! unused
          real*8   user5     ! unused
          real*8   user6     ! unused
          real*8   user7     ! unused
          real*8   user8     ! unused
          real*8   user9     ! unused
          real*8   user10    ! unused
          real*8   user11    ! unused
          real*8   user12    ! unused
          integer*4 user_i1  ! parent_int_id of the creating coll/decay
          integer*4 user_i2  ! n_coll of that interaction, from the primary
          integer*4 user_i3  ! n_decay of that interaction, from the primary
          integer*4 user_i4  ! unused
          integer*4 user_i5  ! parent_sec_id in that interaction

! particle information at production
          type(ptcl):: inip    ! basic ptcl attributes.
          type(position):: inipos
          real*8 init           ! time in length/beta (m)
          type(direc):: inivec

! parent particle information 
          type(ptcl):: parp    ! basic ptcl attributes.
          type(direc):: parvec

#if LABELING > 0
          integer  label     ! put a label (1,2,...) on each particle.
                             ! There is a global label_counter which
              ! is cleared at the start of 1 event generation.
              ! it is counted up when a particle is poped up from the
              ! stack. The label_counter is given to the label of 
              ! the poped up particle. This may be needed to judge
              ! if the same particle crosses a given observation place
              ! more than once.
           integer  info      ! for each particle,  when a particle is born
              !     this is initialized to 0.  If the ptcl goes higher than
              !     380km, 1 is added. This is for AMS observation.
#endif
      end type track
!   #endif  /* Ztrack.h */


