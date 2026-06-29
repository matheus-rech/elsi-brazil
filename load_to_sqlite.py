import pandas as pd
import sqlite3

def main():
    print("Loading cleaned Wave datasets...")
    df1 = pd.read_csv("elsi_wave1_cleaned.csv")
    df2 = pd.read_csv("elsi_wave2_cleaned.csv")
    df3 = pd.read_csv("elsi_wave3_cleaned.csv")
    
    print("Pooling all waves into a combined dataset...")
    df_all = pd.concat([df1, df2, df3], ignore_index=True)
    
    db_file = "elsi_brazil.db"
    print(f"Connecting to SQLite database: {db_file}...")
    conn = sqlite3.connect(db_file)
    
    print("Writing tables to database...")
    # Write individual waves
    df1.to_sql("wave1", conn, if_exists="replace", index=False)
    df2.to_sql("wave2", conn, if_exists="replace", index=False)
    df3.to_sql("wave3", conn, if_exists="replace", index=False)
    # Write pooled dataset
    df_all.to_sql("pooled_waves", conn, if_exists="replace", index=False)
    
    print("Verification of database tables:")
    cursor = conn.cursor()
    # Get tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = [t[0] for t in cursor.fetchall()]
    print("Tables in database:", tables)
    
    # Get counts
    for table in tables:
        cursor.execute(f"SELECT COUNT(*) FROM {table};")
        count = cursor.fetchone()[0]
        print(f"  Table '{table}': {count} rows")
        
    conn.close()
    print("SQLite database successfully created and verified!")

if __name__ == "__main__":
    main()
