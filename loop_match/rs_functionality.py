import json
import random
import time
from web3 import Web3
from datetime import datetime

contract_path = '../build/contracts/ResourceSharing.json'
ganache_url = 'http://localhost:7545'
print_delimiter = '=========='
max_match_interval = 100 * 1000


class ResourceSharing:
    def __init__(self, contract_addr=''):
        self.contract_addr = contract_addr
        self.contract = None
        self.accounts = None
        self.web3 = None

    def deploy_contract(self):
        web3 = Web3(Web3.HTTPProvider(ganache_url))
        self.web3 = web3
        if self.contract_addr == "":
            with open(contract_path) as f:
                config = json.loads(f.read())
            print(f"connected: {web3.isConnected()}")
            print(f"block number: {web3.eth.blockNumber}")
            print(f"accounts: {web3.eth.accounts}")
            self.accounts = web3.eth.accounts
            web3.eth.defaultAccount = web3.eth.accounts[0]
            rs = web3.eth.contract(abi=config['abi'], bytecode=config['bytecode'])
            tx_hash = rs.constructor().transact()
            tx_receipt = web3.eth.waitForTransactionReceipt(tx_hash)
            self.contract_addr = tx_receipt.contractAddress

        # TODO: link current contract
        self.contract = web3.eth.contract(
            address=self.contract_addr,
            abi=config['abi'],
        )
        print(f"\ncontract deployed!\ncontract address: {self.contract_addr}\n")

    def add_provider(self, name, city, target, start, end):
        print(f"add provider, name={name}, city={city}, target={target}, start={start}, end={end}")
        for retry in range(10):
            try:
                return self.contract.functions.addProvider(name, city, target, start, end).transact()
            except Exception as e:
                if retry == 9:
                    print(f"Error in add_provider(): {e}")
                continue

    def add_consumer(self, name, city, budget, duration, deadline):
        print(f"add consumer, name={name}, city={city}, budget={budget}, duration={duration}, deadline={deadline}")
        for retry in range(10):
            try:
                return self.contract.functions.addConsumer(name, city, budget, duration, deadline).transact()
            except Exception as e:
                if retry == 9:
                    print(f"Error in add_provider(): {e}")
                continue

    def get_head(self, city):
        return self.contract.functions.headList(city).call()

    def get_provider(self, _id):
        return self.contract.functions.providerList(_id).call()

    def list_providers(self, city):
        _id = self.get_head(city)
        print(f"\n{print_delimiter} list providers {print_delimiter}")
        while True:
            if self.is_byte32_empty(_id):
                break
            provider = self.get_provider(_id)
            print(f"name={provider[2]}, city={provider[3]}, address={provider[4]}, target={provider[5]}, "
                  f"start={provider[6]}, end={provider[7]}, id={provider[0]}, next={provider[1]}")
            _id = provider[1]

        print(f"//////////////////////////////////////////////////\n")

    def list_matches(self, _address):
        matches = list()
        print(f"\n{print_delimiter} list matches of address {_address} {print_delimiter}")
        idx = 0
        while True:
            try:
                match = self.contract.functions.matchings(_address, idx).call()
                matches.append(match)
                # print(match)
                idx += 1

            except Exception as e:
                break
        print(f"//////////////////////////////////////////////////\n")
        return matches

    @staticmethod
    def is_byte32_empty(_id):
        return Web3.toHex(_id) == '0x0000000000000000000000000000000000000000000000000000000000000000'

    def set_address(self, _address):
        self.web3.eth.defaultAccount = _address

    def get_transaction(self, _address):
        return self.web3.eth.getTransaction(_address)


def unix_now():
    return int(time.mktime(datetime.now().utctimetuple()))


if __name__ == '__main__':
    num = 100
    budget_range = 50
    start_base = 3000000000
    start_range = 10000
    end_base = 4000000000
    end_range = 10000
    duration_base = int((end_base - start_base) * 3 / 4)
    duration_range = int((end_base - start_base) * 1 / 4)
    deadline_base = 5000000000
    cities = ["SF", "LA"]

    for j in range(10):
        rs = ResourceSharing()
        rs.deploy_contract()

        consumer_creation = dict()
        gas_provider = 0
        gas_consumer = 0

        # add providers
        rs.set_address(rs.accounts[0])
        for i in range(num):
            rand = random.random()
            city = cities[int(random.random() * len(cities))]
            tx = rs.add_provider(f"provider #{i}", city, int(budget_range * rand) + 1,
                                 int(start_base + start_range * rand),
                                 int(end_base + end_range * rand))
            gas_provider += rs.get_transaction(tx)['gas']

        rs.set_address(rs.accounts[1])
        # add consumers
        for i in range(num):
            rand = random.random()
            name = f"consumer #{i}"
            consumer_creation[name] = unix_now()
            city = cities[int(random.random() * len(cities))]
            tx = rs.add_consumer(name, city, int(budget_range * rand) + 1, int(duration_base + duration_range * rand),
                                 deadline_base)
            gas_consumer += rs.get_transaction(tx)['gas']

        matches_from = rs.list_matches(rs.accounts[0])
        matches_to = rs.list_matches(rs.accounts[1])
        if len(matches_from) != len(matches_to):
            print(f"Error! len_matches_from={len(matches_from)}, len_matches_to={len(matches_to)}")
        print(f"Engagement:\ntotal={num}, matches={len(matches_from)}, "
              f"engagement_rate={round(len(matches_from) / num * 100, 5)} % ")

        # average matching time cost
        time_total = 0
        for each in matches_from:
            time_total += each[6] - consumer_creation[each[2]]
        print(f"\nMatching time cost:\ntotal={time_total}, num={num}, average_time_cost={time_total / num}s")

        # average gas cost
        print(f"\nAdd provider gas cost:\ntotal={gas_provider}, num={num}, "
              f"average_gas_cost={gas_provider / num}wei = {gas_provider / num / 10 ** 18} ether")
        print(f"\nAdd consumer and matching gas cost:\ntotal={gas_consumer}, num={num}, "
              f"average_gas_cost={gas_consumer / num}wei = {gas_consumer / num / 10 ** 18} ether")