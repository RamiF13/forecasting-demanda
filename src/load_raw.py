from dotenv import load_dotenv
from sqlalchemy import create_engine
import psycopg2
import pandas as pd
import os 
import io
import time

load_dotenv()

host = os.getenv("DB_HOST")
port = os.getenv("DB_PORT")
user = os.getenv("DB_USER")
password = os.getenv("DB_PASSWORD")
base = os.getenv("DB_NAME")

conn = psycopg2.connect(
    dbname=base,
    user=user,
    password=password,
    host=host,
    port=port
)

engine = create_engine(f'postgresql+psycopg2://{user}:{password}@{host}:{port}/{base}')

tables = ['train', 'stores', 'oil', 'holidays_events', 'transactions', 'test', 'sample_submission']

cursor = conn.cursor()

for name in tables:
    inicio = time.time()
    df = pd.read_csv(f'data/raw/{name}.csv')
    df.head(0).to_sql(name, engine, if_exists='replace', index=False)
    buffer = io.StringIO()
    df.to_csv(buffer,index=False, header=False)
    buffer.seek(0)
    cursor.copy_expert(f'COPY {name} FROM STDIN WITH CSV', buffer)
    conn.commit()
    buffer.close()
    fin = time.time()
    print(f'{name} tardó en cargarse {fin-inicio:.2f} segundos')

cursor.close()

conn.close()