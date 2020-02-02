import json
import time
import unittest
from web3 import Web3
from datetime import datetime

contract_path = '../build/contracts/ResourceSharing.json'
ganache_url = 'http://localhost:7545'
max_match_interval = 100 * 1000

start = 7999999999
end = 9999999999


class Provider:
    def __init__(self):
        self.id = None
        self.name = ""
        self.region = ""
        self.address = ""
        self.target = 0
        self.start = 0
        self.end = 0

    @staticmethod
    def new(eth_provider):
        p = Provider()
        p.id = eth_provider[0]
        p.name = eth_provider[1]
        p.region = eth_provider[2]
        p.address = eth_provider[3]
        p.target = eth_provider[4]
        p.start = eth_provider[5]
        p.end = eth_provider[6]
        return p


class ProviderIndex:
    def __init__(self):
        self.id = None
        self.next = None

    @staticmethod
    def new(eth_index):
        v = ProviderIndex()
        v.id = eth_index[0]
        v.next = eth_index[1]
        return v


class Consumer:
    def __init__(self):
        self.id = None
        self.next = None
        self.name = ""
        self.region = ""
        self.address = ""
        self.budget = 0
        self.duration = 0
        self.deadline = 0

    @staticmethod
    def new(eth_consumer):
        p = Consumer()
        p.id = eth_consumer[0]
        p.next = eth_consumer[1]
        p.name = eth_consumer[2]
        p.region = eth_consumer[3]
        p.address = eth_consumer[4]
        p.budget = eth_consumer[5]
        p.duration = eth_consumer[6]
        p.deadline = eth_consumer[7]
        return p


class Matching:
    def __init__(self):
        self.provider_name = ""
        self.provider_addr = ""
        self.consumer_name = ""
        self.consumer_addr = ""
        self.region = ""
        self.price = 0
        self.matched_time = 0
        self.start = 0
        self.duration = 0

    @staticmethod
    def new(eth_matching):
        p = Matching()
        p.provider_name = eth_matching[0]
        p.provider_addr = eth_matching[1]
        p.consumer_name = eth_matching[2]
        p.consumer_addr = eth_matching[3]
        p.region = eth_matching[4]
        p.price = eth_matching[5]
        p.matched_time = eth_matching[6]
        p.start = eth_matching[7]
        p.duration = eth_matching[8]
        return p


class TestResourceSharing(unittest.TestCase):
    def deploy(self):
        web3 = Web3(Web3.HTTPProvider(ganache_url))
        self.web3 = web3

        with open(contract_path) as f:
            config = json.loads(f.read())
        self.accounts = web3.eth.accounts
        web3.eth.defaultAccount = web3.eth.accounts[0]
        rs = web3.eth.contract(abi=config['abi'], bytecode=config['bytecode'])
        tx_hash = rs.constructor().transact()
        tx_receipt = web3.eth.waitForTransactionReceipt(tx_hash)

        contract = web3.eth.contract(
            address=tx_receipt.contractAddress,
            abi=config['abi'],
        )
        print(f"\ncontract deployed!\ncontract address: {tx_receipt.contractAddress}\n")
        return contract

    def test_bad_provider(self):
        rs = self.deploy()
        rs.functions.addProvider("hello", "SF", 1, 1, 1)
        head = rs.functions.headMap("SF").call()
        self.assertTrue(self.is_byte32_empty(head), "bad end time, head should be empty")

        rs.functions.addProvider("hello", "SF", 1, 9999999999, 7999999999)
        head = rs.functions.headMap("SF").call()
        self.assertTrue(self.is_byte32_empty(head), "bad start time, head should be empty")

    def test_add_providers(self):
        rs = self.deploy()
        rs.functions.addProvider("hello", "SF", 3, start + 1, end).transact()
        rs.functions.addProvider("world", "SF", 2, start, end).transact()
        rs.functions.addProvider("test", "SF", 1, start, end).transact()
        rs.functions.addProvider("provider4", "SF", 4, start, end + 1).transact()

        key = "SF||min_latency"
        cur_bytes = rs.functions.headMap(key).call()
        self.assertFalse(self.is_byte32_empty(cur_bytes), "head should not be empty")

        index = ProviderIndex.new(rs.functions.providerIndexMap(key, cur_bytes).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("test", current.name)
        self.assertEqual("SF", current.region)
        self.assertEqual(1, current.target)
        self.assertEqual(start, current.start)
        self.assertEqual(end, current.end)

        index = ProviderIndex.new(rs.functions.providerIndexMap(key, index.next).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("world", current.name)
        self.assertEqual("SF", current.region)
        self.assertEqual(2, current.target)
        self.assertEqual(start, current.start)
        self.assertEqual(end, current.end)

        index = ProviderIndex.new(rs.functions.providerIndexMap(key, index.next).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("hello", current.name)
        self.assertEqual("SF", current.region)
        self.assertEqual(3, current.target)
        self.assertEqual(start + 1, current.start)
        self.assertEqual(end, current.end)

        index = ProviderIndex.new(rs.functions.providerIndexMap(key, index.next).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("provider4", current.name)
        self.assertEqual("SF", current.region)
        self.assertEqual(4, current.target)
        self.assertEqual(start, current.start)
        self.assertEqual(end + 1, current.end)
        self.assertTrue(self.is_byte32_empty(index.next))

    def test_add_provider_different_regions(self):
        rs = self.deploy()
        rs.functions.addProvider("hello", "SF", 3, start, end).transact()
        rs.functions.addProvider("NYC1", "NYC", 2, start, end).transact()
        rs.functions.addProvider("NYC2", "NYC", 1, start, end).transact()

        key = "SF||min_latency"
        cur_bytes = rs.functions.headMap(key).call()
        self.assertFalse(self.is_byte32_empty(cur_bytes), "head should not be empty")

        index = ProviderIndex.new(rs.functions.providerIndexMap(key, cur_bytes).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("hello", current.name)
        self.assertEqual("SF", current.region)
        self.assertEqual(3, current.target)
        self.assertEqual(start, current.start)
        self.assertEqual(end, current.end)
        self.assertTrue(self.is_byte32_empty(index.next))

        key = "NYC||min_latency"
        cur_bytes = rs.functions.headMap(key).call()
        self.assertFalse(self.is_byte32_empty(cur_bytes), "head should not be empty")

        index = ProviderIndex.new(rs.functions.providerIndexMap(key, cur_bytes).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("NYC2", current.name)
        self.assertEqual("NYC", current.region)
        self.assertEqual(1, current.target)
        self.assertEqual(start, current.start)
        self.assertEqual(end, current.end)

        index = ProviderIndex.new(rs.functions.providerIndexMap(key, index.next).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("NYC1", current.name)
        self.assertEqual("NYC", current.region)
        self.assertEqual(2, current.target)
        self.assertEqual(start, current.start)
        self.assertEqual(end, current.end)
        self.assertTrue(self.is_byte32_empty(index.next))

    def test_remove_expired_provider(self):
        rs = self.deploy()
        rs.functions.addProvider("test", "SF", 1, start, end).transact()

        now = int(datetime.now().timestamp())
        rs.functions.addProvider("remove1", "SF", 1, now, now + 1).transact()

        key = "SF||min_latency"
        cur_bytes = rs.functions.headMap(key).call()
        current = Provider.new(rs.functions.providerMap(cur_bytes).call())
        self.assertEqual("remove1", current.name)
        self.assertEqual(1, current.target)
        self.assertEqual(now, current.start)
        self.assertEqual(now + 1, current.end)

        time.sleep(2)
        rs.functions.removeExpiredProviders(key).transact()

        cur_bytes = rs.functions.headMap(key).call()
        current = Provider.new(rs.functions.providerMap(cur_bytes).call())
        self.assertEqual("test", current.name)

    def test_bad_consumer(self):
        rs = self.deploy()
        self.set_address(self.accounts[0])
        rs.functions.addProvider("test", "SF", 1, start, end).transact()

        key = "SF||min_latency"
        cur_bytes = rs.functions.headMap(key).call()
        self.assertFalse(self.is_byte32_empty(cur_bytes), "head should not be empty")

        rs.functions.addConsumer("min_latency", "hello", "SF", 1, 1000, 1)
        try:
            rs.functions.matchings(self.accounts[0], 0).call()

        except Exception as e:
            return
        self.assertTrue(False, "matching should raise error")

    def test_add_consumer(self):
        rs = self.deploy()
        self.set_address(self.accounts[0])

        region = "SF"
        key = region + "||min_latency"
        rs.functions.addProvider("hello", region, 3, start + 1, end).transact()
        rs.functions.addProvider("world", region, 2, start, end).transact()
        rs.functions.addProvider("test", region, 1, start, end).transact()
        rs.functions.addProvider("provider4", region, 4, start, end + 1).transact()

        self.set_address(self.accounts[1])
        rs.functions.addConsumer("min_latency", "consumer1", region, 2, 100, end).transact()

        cur_bytes = rs.functions.headMap(key).call()
        index = ProviderIndex.new(rs.functions.providerIndexMap(key, cur_bytes).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("world", current.name)
        self.assertEqual(2, current.target)

        index = ProviderIndex.new(rs.functions.providerIndexMap(key, index.next).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("hello", current.name)
        self.assertEqual(3, current.target)

        index = ProviderIndex.new(rs.functions.providerIndexMap(key, index.next).call())
        current = Provider.new(rs.functions.providerMap(index.id).call())
        self.assertEqual("provider4", current.name)
        self.assertEqual(4, current.target)
        self.assertTrue(self.is_byte32_empty(index.next))

        # match
        match = Matching.new(rs.functions.matchings(self.accounts[0], 0).call())
        self.assertEqual("test", match.provider_name)
        self.assertEqual(self.accounts[0], match.provider_addr)
        self.assertEqual("consumer1", match.consumer_name)
        self.assertEqual(self.accounts[1], match.consumer_addr)
        self.assertEqual(region, match.region)
        self.assertEqual(1, match.price)
        self.assertEqual(start, match.start)
        self.assertEqual(100, match.duration)

    @staticmethod
    def is_byte32_empty(_id):
        return Web3.toHex(_id) == '0x0000000000000000000000000000000000000000000000000000000000000000'

    def set_address(self, _address):
        self.web3.eth.defaultAccount = _address


if __name__ == '__main__':
    unittest.main()
