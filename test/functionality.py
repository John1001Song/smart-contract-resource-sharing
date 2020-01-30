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
maxMatchInterval = 100 * 1000


class Provider:
    def __init__(self):
        self.id = None
        self.next = None
        self.name = ""
        self.address = ""
        self.target = 0
        self.start = 0
        self.end = 0

    @staticmethod
    def new(eth_provider):
        p = Provider()
        p.id = eth_provider[0]
        p.next = eth_provider[1]
        p.name = eth_provider[2]
        p.address = eth_provider[3]
        p.target = eth_provider[4]
        p.start = eth_provider[5]
        p.end = eth_provider[6]
        return p


class Consumer:
    def __init__(self):
        self.id = None
        self.next = None
        self.name = ""
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
        p.address = eth_consumer[3]
        p.budget = eth_consumer[4]
        p.duration = eth_consumer[5]
        p.deadline = eth_consumer[6]
        return p


class Matching:
    def __init__(self):
        self.provider_name = ""
        self.provider_addr = ""
        self.consumer_name = ""
        self.consumer_addr = ""
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
        p.price = eth_matching[4]
        p.matched_time = eth_matching[5]
        p.start = eth_matching[6]
        p.duration = eth_matching[7]
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
        rs.functions.addProvider("hello", 1, 1, 1)
        head = rs.functions.head().call()
        self.assertTrue(self.is_byte32_empty(head), "bad end time, head should be empty")

        rs.functions.addProvider("hello", 1, 9999999999, 7999999999)
        head = rs.functions.head().call()
        self.assertTrue(self.is_byte32_empty(head), "bad start time, head should be empty")

    def test_add_providers(self):
        rs = self.deploy()
        rs.functions.addProvider("hello", 3, start + 1, end).transact()
        rs.functions.addProvider("world", 2, start, end).transact()
        rs.functions.addProvider("test", 1, start, end).transact()
        rs.functions.addProvider("provider4", 4, start, end + 1).transact()

        cur_bytes = rs.functions.head().call()
        self.assertFalse(self.is_byte32_empty(cur_bytes), "head should not be empty")

        current = Provider.new(rs.functions.providerList(cur_bytes).call())
        self.assertEqual(current.name, "test")
        self.assertEqual(current.target, 1)
        self.assertEqual(current.start, start)
        self.assertEqual(current.end, end)

        current = Provider.new(rs.functions.providerList(current.next).call())
        self.assertEqual(current.name, "world")
        self.assertEqual(current.target, 2)
        self.assertEqual(current.start, start)
        self.assertEqual(current.end, end)

        current = Provider.new(rs.functions.providerList(current.next).call())
        self.assertEqual(current.name, "hello")
        self.assertEqual(current.target, 3)
        self.assertEqual(current.start, start + 1)
        self.assertEqual(current.end, end)

        current = Provider.new(rs.functions.providerList(current.next).call())
        self.assertEqual(current.name, "provider4")
        self.assertEqual(current.target, 4)
        self.assertEqual(current.start, start)
        self.assertEqual(current.end, end + 1)
        self.assertTrue(self.is_byte32_empty(current.next))

    def test_remove_expired_provider(self):
        rs = self.deploy()
        rs.functions.addProvider("test", 1, start, end).transact()

        now = int(datetime.now().timestamp())
        rs.functions.addProvider("remove1", 1, now, now + 1).transact()

        cur_bytes = rs.functions.head().call()
        current = Provider.new(rs.functions.providerList(cur_bytes).call())
        self.assertEqual(current.name, "remove1")
        self.assertEqual(current.target, 1)
        self.assertEqual(current.start, now)
        self.assertEqual(current.end, now + 1)

        time.sleep(2)
        rs.functions.removeExpiredProviders().transact()

        cur_bytes = rs.functions.head().call()
        current = Provider.new(rs.functions.providerList(cur_bytes).call())
        self.assertEqual(current.name, "test")

    def test_bad_consumer(self):
        rs = self.deploy()
        self.set_address(self.accounts[0])
        rs.functions.addProvider("test", 1, start, end).transact()
        cur_bytes = rs.functions.head().call()
        self.assertFalse(self.is_byte32_empty(cur_bytes), "head should not be empty")

        rs.functions.addConsumer("hello", 1, 1000, 1)
        try:
            rs.functions.matchings(self.accounts[0], 0).call()

        except Exception as e:
            return
        self.assertTrue(False, "matching should raise error")

    def test_add_consumer(self):
        rs = self.deploy()
        self.set_address(self.accounts[0])
        rs.functions.addProvider("hello", 3, start + 1, end).transact()
        rs.functions.addProvider("world", 2, start, end).transact()
        rs.functions.addProvider("test", 1, start, end).transact()
        rs.functions.addProvider("provider4", 4, start, end + 1).transact()

        self.set_address(self.accounts[1])
        rs.functions.addConsumer("consumer1", 2, 100, end).transact()

        cur_bytes = rs.functions.head().call()
        current = Provider.new(rs.functions.providerList(cur_bytes).call())
        self.assertEqual(current.name, "world")
        self.assertEqual(current.target, 2)

        current = Provider.new(rs.functions.providerList(current.next).call())
        self.assertEqual(current.name, "hello")
        self.assertEqual(current.target, 3)

        current = Provider.new(rs.functions.providerList(current.next).call())
        self.assertEqual(current.name, "provider4")
        self.assertEqual(current.target, 4)
        self.assertTrue(self.is_byte32_empty(current.next))

        # match
        match = Matching.new(rs.functions.matchings(self.accounts[0], 0).call())
        self.assertEqual(match.provider_name, "test")
        self.assertEqual(match.provider_addr, self.accounts[0])
        self.assertEqual(match.consumer_name, "consumer1")
        self.assertEqual(match.consumer_addr, self.accounts[1])
        self.assertEqual(match.price, 1)
        self.assertEqual(match.start, start)
        self.assertEqual(match.duration, 100)

    @staticmethod
    def is_byte32_empty(_id):
        return Web3.toHex(_id) == '0x0000000000000000000000000000000000000000000000000000000000000000'

    def set_address(self, _address):
        self.web3.eth.defaultAccount = _address


if __name__ == '__main__':
    unittest.main()
