import json
import random
import time
from web3 import Web3
from datetime import datetime
from tests.functionality import Provider, Consumer, Matching

contract_path = '../build/contracts/ResourceSharing.json'
ganache_url = 'http://localhost:7545'
print_delimiter = '=========='
max_match_interval = 100 * 1000
save_dir = '../statistics/'
all_cities = ["SF", "NYC", "SH", "LA"]


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
                return self.contract.functions.addProvider("min_latency", name, city, target, start, end).transact()
            except Exception as e:
                print(f"Error in add_provider(): {e}")
                if retry == 9:
                    print(f"Error in add_provider(): {e}")
                continue

    def add_consumer(self, name, city, budget, duration, deadline, mode="min_latency"):
        print(f"add consumer, name={name}, city={city}, budget={budget}, duration={duration}, deadline={deadline}")
        for retry in range(10):
            try:
                return self.contract.functions.addConsumer(mode, name, city, budget, duration, deadline).transact()
            except Exception as e:
                print(f"Error in add_provider(): {e}")
                if retry == 9:
                    print(f"Error in add_provider(): {e}")
                continue

    def get_head(self, city, mode="min_latency"):
        return self.contract.functions.headMap(f"{city}||{mode}").call()

    def get_provider(self, _id):
        return Provider.new(self.contract.functions.providerMap(_id).call())

    def get_provider_list(self, _id, city, mode="min_latency"):
        return self.contract.functions.providerIndexMap(f"{city}||{mode}", _id).call()

    def list_providers(self, city):
        provider_list = []
        _id = self.get_head(city)
        print(f"\n{print_delimiter} list providers {print_delimiter}")
        while True:
            if self.is_byte32_empty(_id):
                break
            provider = self.get_provider(_id)
            print(f"provider={provider}")
            provider_list.append(provider)

            index = self.get_provider_list(_id, city)
            _id = index[1]

        print(f"//////////////////////////////////////////////////\n")
        return provider_list

    def list_matches(self, _address):
        matches = list()
        print(f"\n{print_delimiter} list matches of address {_address} {print_delimiter}")
        idx = 0
        while True:
            try:
                match = self.contract.functions.matchings(_address, idx).call()
                matches.append(Matching.new(match))
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


def log_and_save(p, msg):
    print(msg)
    with open(p, "a") as f:
        f.write(msg)
        f.write("\n")


def run(num, budget_range, city_num):
    cities = all_cities[:city_num]
    start_base = 3000000000
    start_range = 10000
    end_base = 4000000000
    end_range = 10000
    duration_base = int((end_base - start_base) * 3 / 4)
    duration_range = int((end_base - start_base) * 1 / 4)
    deadline_base = 5000000000

    filename = f"rs_{len(cities)}city_budget{budget_range}_{num}v{num}"
    save_path = f"{save_dir}{filename}"

    for j in range(1):
        rs = ResourceSharing()
        rs.deploy_contract()

        consumer_creation = dict()
        gas_provider = 0
        gas_consumer = 0

        for i in range(num):
            rs.set_address(rs.accounts[0])

            # add providers
            city = cities[int(random.random() * len(cities))]
            tx = rs.add_provider(f"provider #{i}", city, int(budget_range * random.random()) + 1,
                                 int(start_base + start_range * random.random()),
                                 int(end_base + end_range * random.random()))
            print(f"gas used: {rs.get_transaction(tx)['gas']}")
            gas_provider += rs.get_transaction(tx)['gas']

        for i in range(num):
            # add consumer
            city = cities[int(random.random() * len(cities))]
            rs.set_address(rs.accounts[1])
            name = f"consumer #{i}"
            consumer_creation[name] = unix_now()
            tx = rs.add_consumer(name, city, int(budget_range * random.random()) + 1,
                                 int(duration_base + duration_range * random.random()),
                                 deadline_base)
            print(f"gas used: {rs.get_transaction(tx)['gas']}")
            gas_consumer += rs.get_transaction(tx)['gas']

        matches_from = rs.list_matches(rs.accounts[0])
        matches_to = rs.list_matches(rs.accounts[1])
        if len(matches_from) != len(matches_to):
            msg = f"Error! len_matches_from={len(matches_from)}, len_matches_to={len(matches_to)}"
            log_and_save(save_path, msg)
        msg = f"Engagement:\ntotal={num}, matches={len(matches_from)}, " \
            f"engagement_rate={round(len(matches_from) / num * 100, 5)} % "
        log_and_save(save_path, msg)

        # average matching time cost
        time_total = 0
        for each in matches_from:
            time_total += each.matched_time - consumer_creation[each.matcher2_name]
        msg = f"\nMatching time cost:\ntotal={time_total}s, num={num}, average_time_cost={time_total / num}s"
        log_and_save(save_path, msg)

        # average gas cost
        msg = f"\nAdd provider gas cost:\ntotal={gas_provider}, num={num}, " \
            f"average_gas_cost={gas_provider / num}wei = {gas_provider / num / 10 ** 18} ether"
        log_and_save(save_path, msg)
        msg = f"\nAdd consumer and matching gas cost:\ntotal={gas_consumer}, num={num}, " \
            f"average_gas_cost={gas_consumer / num}wei = {gas_consumer / num / 10 ** 18} ether"
        log_and_save(save_path, msg)
        log_and_save(save_path, "\n\n")


if __name__ == '__main__':
    for i in range(10):
        run(25, 5, 2)
