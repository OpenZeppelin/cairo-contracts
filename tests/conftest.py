import pytest
import asyncio

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()
