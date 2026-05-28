from motor.motor_asyncio import AsyncIOMotorClient
from config import MONGODB_URI, DB_NAME

client: AsyncIOMotorClient = None


async def connect_db():
    global client
    client = AsyncIOMotorClient(MONGODB_URI)
    print(f'Connected to MongoDB: {DB_NAME}')


async def close_db():
    global client
    if client:
        client.close()


def get_db():
    return client[DB_NAME]


def get_users_collection():
    return get_db()['users']


def get_scans_collection():
    return get_db()['scans']
