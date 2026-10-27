
import argparse
import h5py


def inspect_hdf5(filename):
    """HDF5ファイルのグループ、テーブル、Attributes、Keysを表示する。"""

    with h5py.File(filename, "r") as f:
        print("=" * 80)
        print(f"HDF5 File: {filename}")
        print("=" * 80)

        def inspect_item(name, obj):
            if isinstance(obj, h5py.Group):
                print(f"\n[Group] {name}")

                if len(obj.attrs) > 0:
                    print("  Attributes:")
                    for attr_name, attr_value in obj.attrs.items():
                        print(f"    {attr_name}: {attr_value}")

            elif isinstance(obj, h5py.Dataset):
                print(f"\n[Dataset / Table] {name}")
                print(f"  Shape: {obj.shape}")
                print(f"  Dtype: {obj.dtype}")

                print("  Attributes:")
                if len(obj.attrs) == 0:
                    print("    (none)")
                else:
                    for attr_name, attr_value in obj.attrs.items():
                        print(f"    {attr_name}: {attr_value}")

                print("  Keys:")
                if obj.dtype.names is not None:
                    for key in obj.dtype.names:
                        print(f"    {key}")
                else:
                    print("    (structured columns not found)")

        f.visititems(inspect_item)


def main():
    parser = argparse.ArgumentParser(
        description="Inspect groups, datasets, attributes, and keys in an HDF5 file."
    )
    parser.add_argument(
        "filename",
        help="Path to the HDF5 file"
    )
    args = parser.parse_args()

    inspect_hdf5(args.filename)


if __name__ == "__main__":
    main()

