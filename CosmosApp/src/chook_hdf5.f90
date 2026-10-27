! One air-shower event, one HDF5 file.
!
! /conditions                 attributes of the primary and the run
! /interactions/Int_<id>     one compound dataset per coll or decay
! /observation/Obs_<plane>   one compound dataset per observation plane
!
! Int_<id> rows are the produced particles, id starting at 1.
! Obs_<plane> rows are particles that reached that plane.
! Particle identities are PDG codes. Energies and momenta are GeV.
! Heights and positions are metres. Zenith angle is degrees.
! xlab = E_secondary / E_projectile.
! pt_gev is the momentum component perpendicular to the projectile.
! n_coll and n_decay count collisions and decays from the primary
! up to and including this interaction.
! parent_int_id / parent_sec_id on an interaction are the projectile's
! origin. On an observation they are the last coll or decay ancestor.
! Electromagnetic products keep that ancestor. Primary ids are 0.
! Walk parent_int_id until it is 0 to reach the primary.
! Decay has target_a = target_z = target_pdg = 0.
! target_pdg is the PDG ion code 10LZZZAAAI.
!
! The file path is $COSMOS_H5OUT, or output/event_<event>.h5.

module chook_hdf5
  use hdf5
  use iso_c_binding
  use iso_fortran_env, only: error_unit
  implicit none
  private

  public :: shower_h5_begin
  public :: shower_h5_interaction
  public :: shower_h5_observe
  public :: shower_h5_end

  integer, parameter :: sec_fields = 8
  integer, parameter :: obs_fields = 9
  integer, parameter :: name_len = 16
  integer, parameter :: max_planes = 20
  integer(c_int), parameter :: gzip_level = 6_c_int
  integer(c_size_t), parameter :: int_chunk_rows = 256_c_size_t
  integer(c_size_t), parameter :: obs_chunk_rows = 8192_c_size_t

  type, bind(c) :: sec_record
    integer(c_int) :: sec_id
    integer(c_int) :: pdg
    real(c_double) :: energy_gev
    real(c_double) :: px_gev
    real(c_double) :: py_gev
    real(c_double) :: pz_gev
    real(c_double) :: xlab
    real(c_double) :: pt_gev
  end type sec_record

  type, bind(c) :: obs_record
    integer(c_int) :: pdg
    real(c_double) :: energy_gev
    real(c_double) :: px_gev
    real(c_double) :: py_gev
    real(c_double) :: pz_gev
    real(c_double) :: x_m
    real(c_double) :: y_m
    integer(c_int) :: parent_int_id
    integer(c_int) :: parent_sec_id
  end type obs_record

  type plane_buf
    integer :: id = 0
    real(8) :: height = 0.d0
    integer :: n = 0
    type(obs_record), allocatable :: rows(:)
  end type plane_buf

  interface
    function h5tbmake_table_c(title, loc_id, dset_name, nfields, nrecords, &
         type_size, field_names, field_offset, field_types, chunk_size, &
         fill_data, compress, buf) bind(c, name="H5TBmake_table") result(herr)
      import :: c_char, c_int, c_int64_t, c_ptr, c_size_t
      character(kind=c_char), intent(in) :: title(*)
      integer(c_int64_t), value :: loc_id
      character(kind=c_char), intent(in) :: dset_name(*)
      integer(c_size_t), value :: nfields
      integer(c_size_t), value :: nrecords
      integer(c_size_t), value :: type_size
      type(c_ptr), value :: field_names
      type(c_ptr), value :: field_offset
      type(c_ptr), value :: field_types
      integer(c_size_t), value :: chunk_size
      type(c_ptr), value :: fill_data
      integer(c_int), value :: compress
      type(c_ptr), value :: buf
      integer(c_int) :: herr
    end function h5tbmake_table_c
  end interface

  integer(hid_t) :: file_id = -1
  integer(hid_t) :: cond_id = -1
  integer(hid_t) :: int_id = -1
  integer(hid_t) :: obs_id = -1
  logical :: file_is_open = .false.
  logical :: layout_ready = .false.
  integer :: n_interactions = 0
  integer :: n_observed = 0
  character(len=512) :: filename = ""

  type(plane_buf) :: planes(max_planes)
  integer :: nplanes = 0

  integer(size_t) :: sec_type_size, obs_type_size
  integer(size_t), target :: sec_offset(sec_fields), obs_offset(obs_fields)
  integer(hid_t), target :: sec_types(sec_fields), obs_types(obs_fields)
  character(len=name_len) :: sec_names(sec_fields), obs_names(obs_fields)

contains

  subroutine shower_h5_begin(event_no, pdg, energy, px, py, pz, &
       zenith_deg, model, height, nplane, plane_height)
    integer, intent(in) :: event_no, pdg, nplane
    real(8), intent(in) :: energy, px, py, pz, zenith_deg, height
    character(len=*), intent(in) :: model
    real(8), intent(in) :: plane_height(:)
    character(len=512) :: env
    integer :: stat, err, i

    if (file_is_open) call shower_h5_end

    call get_environment_variable("COSMOS_H5OUT", env, status=stat)
    if (stat /= 0 .or. len_trim(env) == 0) then
      write(filename, '("output/event_", i6.6, ".h5")') event_no
    else
      filename = env
    end if
    call ensure_parent(trim(filename))

    call h5open_f(err)
    call check("h5open", err)
    call h5fcreate_f(trim(filename), H5F_ACC_TRUNC_F, file_id, err)
    call check("h5fcreate", err)
    file_is_open = .true.
    n_interactions = 0
    n_observed = 0
    call init_layout

    call h5gcreate_f(file_id, "conditions", cond_id, err)
    call check("h5gcreate conditions", err)
    call h5gcreate_f(file_id, "interactions", int_id, err)
    call check("h5gcreate interactions", err)
    call h5gcreate_f(file_id, "observation", obs_id, err)
    call check("h5gcreate observation", err)

    call put_string_id(file_id, "format", "cosmos-airshower-v2")
    call put_int_id(cond_id, "event_number", event_no)
    call put_int_id(cond_id, "pdg", pdg)
    call put_real_id(cond_id, "energy_gev", energy)
    call put_real_id(cond_id, "px_gev", px)
    call put_real_id(cond_id, "py_gev", py)
    call put_real_id(cond_id, "pz_gev", pz)
    call put_real_id(cond_id, "zenith_deg", zenith_deg)
    call put_string_id(cond_id, "interaction_model", tidy_text(model))
    call put_real_id(cond_id, "height_m", height)
    call put_string_id(cond_id, "units", &
         "energy and momentum GeV, zenith degree, height m, pdg code")

    if (nplane > max_planes) then
      write(error_unit, "(a,i4)") "too many observation planes: ", nplane
      stop 1
    end if
    nplanes = nplane
    do i = 1, nplanes
      planes(i)%id = i
      planes(i)%height = plane_height(i)
      planes(i)%n = 0
      if (allocated(planes(i)%rows)) deallocate(planes(i)%rows)
      allocate(planes(i)%rows(1024))
    end do

    write(error_unit, "(a,a)") "HDF5 output: ", trim(filename)
  end subroutine shower_h5_begin

  subroutine shower_h5_interaction(int_no, proj_pdg, proj_e, proj_px, &
       proj_py, proj_pz, target_a, target_z, target_pdg, height, &
       x, y, z, process, n_coll, n_decay, parent_int, parent_sec, &
       nsec, sec_pdg, energy, px, py, pz, xlab, pt)
    integer, intent(in) :: int_no, proj_pdg, target_a, target_z, target_pdg
    integer, intent(in) :: n_coll, n_decay, parent_int, parent_sec, nsec
    integer, intent(in) :: sec_pdg(:)
    real(8), intent(in) :: proj_e, proj_px, proj_py, proj_pz, height
    real(8), intent(in) :: x, y, z
    real(8), intent(in) :: energy(:), px(:), py(:), pz(:), xlab(:), pt(:)
    character(len=*), intent(in) :: process
    type(sec_record), allocatable, target :: rows(:)
    type(c_ptr) :: buf
    character(len=32) :: dname
    integer(hid_t) :: dset
    integer :: i, err

    call require_open("shower_h5_interaction")
    if (nsec > 0) then
      allocate(rows(nsec))
      do i = 1, nsec
        rows(i)%sec_id = int(i, c_int)
        rows(i)%pdg = int(sec_pdg(i), c_int)
        rows(i)%energy_gev = energy(i)
        rows(i)%px_gev = px(i)
        rows(i)%py_gev = py(i)
        rows(i)%pz_gev = pz(i)
        rows(i)%xlab = xlab(i)
        rows(i)%pt_gev = pt(i)
      end do
      buf = c_loc(rows(1))
    else
      buf = c_null_ptr
    end if

    write(dname, '("Int_", i0)') int_no
    call make_table(int_id, trim(dname), "interaction", sec_fields, &
         sec_names, sec_offset, sec_types, sec_type_size, nsec, buf, &
         int_chunk_rows)

    call h5dopen_f(int_id, trim(dname), dset, err)
    call check("h5dopen interaction", err)
    call put_real_id(dset, "projectile_energy_gev", proj_e)
    call put_real_id(dset, "projectile_px_gev", proj_px)
    call put_real_id(dset, "projectile_py_gev", proj_py)
    call put_real_id(dset, "projectile_pz_gev", proj_pz)
    call put_int_id(dset, "projectile_pdg", proj_pdg)
    call put_int_id(dset, "target_a", target_a)
    call put_int_id(dset, "target_z", target_z)
    call put_int_id(dset, "target_pdg", target_pdg)
    call put_int_id(dset, "int_id", int_no)
    call put_real_id(dset, "height_m", height)
    call put_real_id(dset, "x_m", x)
    call put_real_id(dset, "y_m", y)
    call put_real_id(dset, "z_m", z)
    call put_string_id(dset, "process", trim(process))
    call put_int_id(dset, "n_secondaries", nsec)
    call put_int_id(dset, "n_coll", n_coll)
    call put_int_id(dset, "n_decay", n_decay)
    call put_int_id(dset, "parent_int_id", parent_int)
    call put_int_id(dset, "parent_sec_id", parent_sec)
    call put_string_id(dset, "units", &
         "energy and momentum GeV, position m, xlab dimensionless, pt GeV/c")
    call h5dclose_f(dset, err)
    n_interactions = n_interactions + 1
  end subroutine shower_h5_interaction

  subroutine shower_h5_observe(plane, pdg, energy, px, py, pz, x, y, &
       parent_int, parent_sec)
    integer, intent(in) :: plane, pdg, parent_int, parent_sec
    real(8), intent(in) :: energy, px, py, pz, x, y
    type(obs_record) :: rec

    if (.not. file_is_open) return
    if (plane < 1 .or. plane > nplanes) return

    rec%pdg = int(pdg, c_int)
    rec%energy_gev = energy
    rec%px_gev = px
    rec%py_gev = py
    rec%pz_gev = pz
    rec%x_m = x
    rec%y_m = y
    rec%parent_int_id = int(parent_int, c_int)
    rec%parent_sec_id = int(parent_sec, c_int)
    call push_obs(plane, rec)
    n_observed = n_observed + 1
  end subroutine shower_h5_observe

  subroutine shower_h5_end
    character(len=32) :: dname
    type(obs_record), allocatable, target :: packed(:)
    type(c_ptr) :: buf
    integer(hid_t) :: dset
    integer :: i, err, n

    if (.not. file_is_open) return

    do i = 1, nplanes
      n = planes(i)%n
      if (n > 0) then
        if (allocated(packed)) deallocate(packed)
        allocate(packed(n))
        packed = planes(i)%rows(1:n)
        buf = c_loc(packed(1))
      else
        buf = c_null_ptr
      end if
      write(dname, '("Obs_", i0)') planes(i)%id
      call make_table(obs_id, trim(dname), "observation plane", obs_fields, &
           obs_names, obs_offset, obs_types, obs_type_size, n, buf, &
           obs_chunk_rows)
      call h5dopen_f(obs_id, trim(dname), dset, err)
      call check("h5dopen observation", err)
      call put_real_id(dset, "height_m", planes(i)%height)
      call put_int_id(dset, "plane_id", planes(i)%id)
      call put_string_id(dset, "units", &
           "energy and momentum GeV, x y height m")
      call h5dclose_f(dset, err)
      planes(i)%n = 0
      if (allocated(planes(i)%rows)) deallocate(planes(i)%rows)
    end do
    nplanes = 0

    call h5gclose_f(cond_id, err)
    call h5gclose_f(int_id, err)
    call h5gclose_f(obs_id, err)
    call h5fclose_f(file_id, err)
    call check("h5fclose", err)
    call h5close_f(err)
    file_is_open = .false.
    write(error_unit, "(a,a,a,i0,a,i0)") "HDF5 wrote ", trim(filename), &
         "  interactions=", n_interactions, "  observed=", n_observed
  end subroutine shower_h5_end

  subroutine push_obs(ip, rec)
    integer, intent(in) :: ip
    type(obs_record), intent(in) :: rec
    type(obs_record), allocatable :: tmp(:)
    integer :: n, cap

    n = planes(ip)%n
    if (.not. allocated(planes(ip)%rows)) allocate(planes(ip)%rows(1024))
    if (n >= size(planes(ip)%rows)) then
      cap = size(planes(ip)%rows)*2
      allocate(tmp(cap))
      tmp(1:n) = planes(ip)%rows(1:n)
      call move_alloc(tmp, planes(ip)%rows)
    end if
    n = n + 1
    planes(ip)%rows(n) = rec
    planes(ip)%n = n
  end subroutine push_obs

  subroutine init_layout
    type(sec_record), target :: sec
    type(obs_record), target :: obs
    type(c_ptr) :: sec_base, obs_base

    if (layout_ready) return

    sec_names(1) = "sec_id"
    sec_names(2) = "pdg"
    sec_names(3) = "energy_gev"
    sec_names(4) = "px_gev"
    sec_names(5) = "py_gev"
    sec_names(6) = "pz_gev"
    sec_names(7) = "xlab"
    sec_names(8) = "pt_gev"
    sec_base = c_loc(sec)
    sec_offset(1) = byte_offset(sec_base, c_loc(sec%sec_id))
    sec_offset(2) = byte_offset(sec_base, c_loc(sec%pdg))
    sec_offset(3) = byte_offset(sec_base, c_loc(sec%energy_gev))
    sec_offset(4) = byte_offset(sec_base, c_loc(sec%px_gev))
    sec_offset(5) = byte_offset(sec_base, c_loc(sec%py_gev))
    sec_offset(6) = byte_offset(sec_base, c_loc(sec%pz_gev))
    sec_offset(7) = byte_offset(sec_base, c_loc(sec%xlab))
    sec_offset(8) = byte_offset(sec_base, c_loc(sec%pt_gev))
    sec_type_size = int(c_sizeof(sec), size_t)
    sec_types(1:2) = H5T_NATIVE_INTEGER
    sec_types(3:8) = H5T_NATIVE_DOUBLE

    obs_names(1) = "pdg"
    obs_names(2) = "energy_gev"
    obs_names(3) = "px_gev"
    obs_names(4) = "py_gev"
    obs_names(5) = "pz_gev"
    obs_names(6) = "x_m"
    obs_names(7) = "y_m"
    obs_names(8) = "parent_int_id"
    obs_names(9) = "parent_sec_id"
    obs_base = c_loc(obs)
    obs_offset(1) = byte_offset(obs_base, c_loc(obs%pdg))
    obs_offset(2) = byte_offset(obs_base, c_loc(obs%energy_gev))
    obs_offset(3) = byte_offset(obs_base, c_loc(obs%px_gev))
    obs_offset(4) = byte_offset(obs_base, c_loc(obs%py_gev))
    obs_offset(5) = byte_offset(obs_base, c_loc(obs%pz_gev))
    obs_offset(6) = byte_offset(obs_base, c_loc(obs%x_m))
    obs_offset(7) = byte_offset(obs_base, c_loc(obs%y_m))
    obs_offset(8) = byte_offset(obs_base, c_loc(obs%parent_int_id))
    obs_offset(9) = byte_offset(obs_base, c_loc(obs%parent_sec_id))
    obs_type_size = int(c_sizeof(obs), size_t)
    obs_types(1) = H5T_NATIVE_INTEGER
    obs_types(2:7) = H5T_NATIVE_DOUBLE
    obs_types(8:9) = H5T_NATIVE_INTEGER
    layout_ready = .true.
  end subroutine init_layout

  subroutine make_table(loc, dset_name, title, nfields, names, offsets, &
       types, type_size, nrec, buf, chunk)
    integer(hid_t), intent(in) :: loc
    character(len=*), intent(in) :: dset_name, title
    integer, intent(in) :: nfields, nrec
    character(len=name_len), intent(in) :: names(:)
    integer(size_t), target, intent(in) :: offsets(:)
    integer(hid_t), target, intent(in) :: types(:)
    integer(size_t), intent(in) :: type_size
    integer(c_size_t), intent(in) :: chunk
    type(c_ptr), intent(in) :: buf
    character(kind=c_char), allocatable, target :: ctitle(:), cdset(:)
    character(kind=c_char), allocatable, target :: storage(:, :)
    type(c_ptr), allocatable, target :: ptrs(:)
    integer(c_int) :: herr
    integer :: i, j, n

    allocate(storage(name_len + 1, nfields), ptrs(nfields))
    storage = c_null_char
    do i = 1, nfields
      n = len_trim(names(i))
      if (n > name_len) n = name_len
      do j = 1, n
        storage(j, i) = names(i)(j:j)
      end do
      ptrs(i) = c_loc(storage(1, i))
    end do
    ctitle = to_c(title)
    cdset = to_c(dset_name)
    herr = h5tbmake_table_c(ctitle, int(loc, c_int64_t), cdset, &
         int(nfields, c_size_t), int(nrec, c_size_t), &
         int(type_size, c_size_t), c_loc(ptrs), c_loc(offsets), &
         c_loc(types), chunk, c_null_ptr, gzip_level, buf)
    if (herr < 0) call check("H5TBmake_table "//trim(dset_name), int(herr))
  end subroutine make_table

  subroutine put_int_id(obj, attr, value)
    integer(hid_t), intent(in) :: obj
    character(len=*), intent(in) :: attr
    integer, intent(in) :: value
    integer(hsize_t) :: dims(1)
    integer(hid_t) :: space, attr_id
    integer, target :: buf(1)
    integer :: err
    dims(1) = 1
    buf(1) = value
    call h5screate_simple_f(1, dims, space, err)
    call check("h5screate", err)
    call h5acreate_f(obj, attr, H5T_NATIVE_INTEGER, space, attr_id, err)
    call check("h5acreate "//trim(attr), err)
    call h5awrite_f(attr_id, H5T_NATIVE_INTEGER, buf, dims, err)
    call check("h5awrite "//trim(attr), err)
    call h5aclose_f(attr_id, err)
    call h5sclose_f(space, err)
  end subroutine put_int_id

  subroutine put_real_id(obj, attr, value)
    integer(hid_t), intent(in) :: obj
    character(len=*), intent(in) :: attr
    real(8), intent(in) :: value
    integer(hsize_t) :: dims(1)
    integer(hid_t) :: space, attr_id
    real(8), target :: buf(1)
    integer :: err
    dims(1) = 1
    buf(1) = value
    call h5screate_simple_f(1, dims, space, err)
    call check("h5screate", err)
    call h5acreate_f(obj, attr, H5T_NATIVE_DOUBLE, space, attr_id, err)
    call check("h5acreate "//trim(attr), err)
    call h5awrite_f(attr_id, H5T_NATIVE_DOUBLE, buf, dims, err)
    call check("h5awrite "//trim(attr), err)
    call h5aclose_f(attr_id, err)
    call h5sclose_f(space, err)
  end subroutine put_real_id

  subroutine put_string_id(obj, attr, value)
    integer(hid_t), intent(in) :: obj
    character(len=*), intent(in) :: attr, value
    integer(hid_t) :: space, atype, attr_id
    integer(hsize_t) :: dims(1)
    integer(size_t) :: slen
    character(len=:), allocatable, target :: buf
    integer :: err
    if (len_trim(value) < 1) then
      buf = " "
    else
      buf = trim(value)
    end if
    slen = int(len(buf), size_t)
    dims(1) = 1
    call h5screate_f(H5S_SCALAR_F, space, err)
    call check("h5screate", err)
    call h5tcopy_f(H5T_C_S1, atype, err)
    call h5tset_size_f(atype, slen, err)
    call h5acreate_f(obj, attr, atype, space, attr_id, err)
    call check("h5acreate "//trim(attr), err)
    call h5awrite_f(attr_id, atype, buf, dims, err)
    call check("h5awrite "//trim(attr), err)
    call h5aclose_f(attr_id, err)
    call h5tclose_f(atype, err)
    call h5sclose_f(space, err)
  end subroutine put_string_id

  subroutine ensure_parent(path)
    character(len=*), intent(in) :: path
    integer :: slash, stat, cmdstat
    character(len=512) :: dir
    slash = index(path, "/", back=.true.)
    if (slash <= 1) return
    dir = path(1:slash - 1)
    call execute_command_line("mkdir -p "//trim(dir), exitstat=stat, &
         cmdstat=cmdstat)
    if (cmdstat /= 0 .or. stat /= 0) then
      write(error_unit, "(a,a)") "cannot create directory ", trim(dir)
      stop 1
    end if
  end subroutine ensure_parent

  function byte_offset(base, member) result(off)
    type(c_ptr), intent(in) :: base, member
    integer(size_t) :: off
    integer(c_intptr_t) :: ibase, imember
    ibase = transfer(base, 0_c_intptr_t)
    imember = transfer(member, 0_c_intptr_t)
    off = int(imember - ibase, size_t)
  end function byte_offset

  function tidy_text(text) result(out)
    character(len=*), intent(in) :: text
    character(len=:), allocatable :: out
    integer :: n
    n = len_trim(text)
    if (n > 0 .and. text(n:n) == "/") n = n - 1
    do while (n > 0 .and. text(n:n) == " ")
      n = n - 1
    end do
    if (n < 1) then
      out = " "
    else
      out = text(1:n)
    end if
  end function tidy_text

  function to_c(text) result(buf)
    character(len=*), intent(in) :: text
    character(kind=c_char), allocatable :: buf(:)
    integer :: i, n
    n = len_trim(text)
    allocate(buf(n + 1))
    do i = 1, n
      buf(i) = text(i:i)
    end do
    buf(n + 1) = c_null_char
  end function to_c

  subroutine require_open(where)
    character(len=*), intent(in) :: where
    if (.not. file_is_open) then
      write(error_unit, "(a,a)") "HDF5 file is not open in ", trim(where)
      stop 1
    end if
  end subroutine require_open

  subroutine check(label, err)
    character(len=*), intent(in) :: label
    integer, intent(in) :: err
    if (err < 0) then
      write(error_unit, "(a,a,a,i6)") "HDF5 error in ", trim(label), ": ", err
      stop 1
    end if
  end subroutine check

end module chook_hdf5
