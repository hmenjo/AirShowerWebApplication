
import argparse
import h5py
import numpy as np


def show_table(filename, table_name):
    """指定したHDF5テーブルのAttributesと全データを表示する。"""

    with h5py.File(filename, "r") as f:
        if table_name not in f:
            print(f"Error: '{table_name}' not found in {filename}")
            return

        obj = f[table_name]

        if not isinstance(obj, h5py.Dataset):
            print(f"Error: '{table_name}' is not a Dataset/Table.")
            return

        print("=" * 80)
        print(f"File:  {filename}")
        print(f"Table: {table_name}")
        print("=" * 80)

        # Attributesを表示
        print("\n[Attributes]")
        if len(obj.attrs) == 0:
            print("  (none)")
        else:
            for attr_name, attr_value in obj.attrs.items():
                print(f"  {attr_name}: {attr_value}")

        # テーブルの基本情報
        print("\n[Table Information]")
        print(f"  Shape: {obj.shape}")
        print(f"  Dtype: {obj.dtype}")

        # テーブル本体の全データを表示
        print("\n[Table Data]")

        data = obj[()]

        if data.dtype.names is not None:
            # 構造化データ（列名あり）
            print("Columns:", data.dtype.names)
            for row in data:
                print(row)
        else:
            # 通常の配列データ
            print(data)


def main():
    parser = argparse.ArgumentParser(
        description="Display HDF5 table attributes and all data."
    )
    parser.add_argument("filename", help="Path to the HDF5 file")
    parser.add_argument(
        "table_name",
        help="Dataset path inside HDF5, e.g. Run001/Events"
    )

    args = parser.parse_args()
    show_table(args.filename, args.table_name)


if __name__ == "__main__":
    main()

