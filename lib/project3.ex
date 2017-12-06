defmodule SupervisorNode do
  use GenServer

  def counter(pid, node_id) do
    GenServer.cast(pid, {:increase_counter, node_id})
  end

  def track(pid) do
    GenServer.call(pid, :track)
  end

  def handle_call(:track, _from, messages) do
    avg_hops = Enum.at(messages, 0) / Enum.at(messages, 1)
    IO.puts avg_hops
    {:reply, messages, messages}
  end

  def handle_cast({:increase_counter, node_id}, messages) do
    hops = Enum.at(messages, 0) + 1
    messages = List.replace_at(messages, 0, hops)
    {:noreply, messages}
  end
end

defmodule PastryNode do
  use GenServer

  def init(messages) do
    {:ok, messages}
  end

  def make_pastry(pid, current_node_id, new_node_id) do
    GenServer.cast(pid, {:make_pastry, current_node_id, new_node_id})
  end

  def start_message(pid, total, destination, hops) do
    GenServer.cast(pid, {:start_message, total, destination, hops})
  end

  defp fetch_random_node(current_node, total_nodes) do
    random_node = :rand.uniform(total_nodes)
    if random_node == current_node do
      fetch_random_node(current_node, total_nodes)
    else
      random_node
    end
  end

  def lcp([]), do: ""
    def lcp(strs) do
    min = Enum.min(strs)
    max = Enum.max(strs)
    index = Enum.find_index(0..String.length(min), fn i -> String.at(min,i) != String.at(max,i) end)
    if index, do: String.slice(min, 0, index), else: min
  end

  defp generate_next_hop(messages, curr_node_id, destination_node) do
    curr_node_id = generate_node_name(curr_node_id)
    leaf_set = Enum.at(messages, 2) ++ Enum.at(messages, 3)
    if destination_node >= Enum.at(leaf_set, 0) and destination_node <= Enum.at(leaf_set, Kernel.length(leaf_set)-1) do
      next_hop = Enum.min_by(leaf_set, &abs(&1 - destination_node)) 
    else
      curr_node_id_hex = Integer.to_string(curr_node_id, 16)
      destination_node_hex = Integer.to_string(destination_node, 16) 
      list = [curr_node_id_hex] ++ [destination_node_hex]
      length_shl = String.length(lcp(list))
      dl = String.at(destination_node_hex, length_shl)
      dl = String.to_integer(dl, 16)
      routes = Enum.at(messages,4)
      rldl = Enum.at(Enum.at(routes, length_shl), dl)
      if rldl != -1 do
        String.to_integer(rldl, 16)
      else
        md5_leaves = Enum.map(leaf_set, fn(x) -> Integer.to_string(x,16) end)
        super_node_set = List.flatten(routes, md5_leaves)
        super_node_set = Enum.filter(super_node_set, fn(x) -> x != -1 end)
        nextNode = rare_case_node(super_node_set, 0, curr_node_id, destination_node, length_shl)
        String.to_integer(nextNode, 16)
      end
    end   
  end

  defp rare_case_node(super_node_set, index, curr_node_id, destination_node, length) do
      if index < Kernel.length super_node_set do
          t = Enum.at(super_node_set, index)
          t_int = String.to_integer(t)
          list = [t] ++ [Integer.to_string(destination_node, 16)]
          len =  lcp(list)
          diff = abs(destination_node - curr_node_id) - abs(t_int - destination_node)
          if len >= length and diff > 0 do
              t
          end
      else
          rare_case_node(super_node_set, index+1, curr_node_id, destination_node, length)
      end
  end 

  def handle_cast({:start_message, total, destination_node, hops}, messages) do
    supervisor_node_name = String.to_atom("supervisor")
    completed_requests = Enum.at(messages, 1)
    if destination_node == Enum.at(messages, 0) do
        messages = List.replace_at(messages,1, completed_requests+1)
    else
      if destination_node == -1 do
        next_hop = message_send(messages, total, destination_node, hops)
        visited_node_list = Enum.at(messages, 5) ++ [next_hop]
        messages = List.replace_at(messages, 5, visited_node_list)
      else
        SupervisorNode.counter(:global.whereis_name(supervisor_node_name), 0)
        next_hop = message_forward(messages, total, destination_node, hops)
        visited_node_list = Enum.at(messages, 5) ++ [next_hop]
        messages = List.replace_at(messages, 5, visited_node_list)
      end
    end
    {:noreply, messages}
  end
  
  defp message_forward(messages, total_nodes, destination, hops) do
    current_index = Enum.at(messages, 0)
    random_node = destination
    node_id = generate_node_name(random_node)
    next_hop = generate_next_hop(messages, current_index, node_id)
    visited_nodes = Enum.at(messages, 5)
    new_node_name = String.to_atom("node#{next_hop}")
    tempMap = visited_nodes |> Enum.reduce(%{}, fn x, acc -> Map.update(acc, x, 1, &(&1 + 1)) end)
    occurence = tempMap[next_hop] 
    if occurence == nil do
      occurence = 0
    end
    if Enum.member?(visited_nodes, next_hop) == true and occurence > 3 do
      ret = []
      ret
    else
      PastryNode.start_message(:global.whereis_name(new_node_name), total_nodes, random_node, hops+1)
      next_hop
    end
  end

  defp message_send(messages, total, destination, hops) do
      current_index = Enum.at(messages, 0)
      random = fetch_random_node(current_index, total)
      node_id = generate_node_name(random)
      next_hop = generate_next_hop(messages, current_index, node_id)
      new_node_name = String.to_atom("node#{next_hop}")
      PastryNode.start_message(:global.whereis_name(new_node_name), total, random, 1)
      next_hop
  end
   

  def handle_cast(:show_states, messages) do
      {:noreply, messages}
  end

  def handle_cast({:make_pastry, current_node_id, new_node_id}, messages) do
      new_messages = messages
      if current_node_id > new_node_id do
          list = Enum.at(messages, 2)
          if Kernel.length(list) > 15 do
              list = List.replace_at(list, 0, new_node_id)
          else
              list = list ++ [new_node_id]
          end
          list = Enum.sort(list)
          new_messages = List.replace_at(messages, 2, list)
      else
          list = Enum.at(messages, 3)
          if Kernel.length(list) > 15 do
              list = List.replace_at(list, 15, new_node_id)
          else
              list = list ++ [new_node_id]
          end
          list = Enum.sort(list)
          new_messages = List.replace_at(messages, 3, list)
      end

      current_node_hex = Integer.to_string(current_node_id, 16)
      new_node_hex = Integer.to_string(new_node_id, 16)
      routing_table_length = Kernel.length(Enum.at(messages, 4))
      new_routing_table = update_routing_table(Enum.at(messages, 4), routing_table_length, new_node_hex, current_node_hex)
      new_messages = List.replace_at(new_messages, 4, new_routing_table)
      {:noreply, new_messages}
  end

  defp update_routing_table(routes, len, new_node_hex, current) do
      if len > 0 do
        temp = String.at(new_node_hex, len-1)
          if temp != nil do
              index = String.to_integer(temp, 16)
              current_routing_value = Enum.at(Enum.at(routes, len-1), index)
              if current_routing_value == -1 do
                  list = Enum.at(routes, len-1);
                  list = List.replace_at(list, index, new_node_hex)
                  routes = List.replace_at(routes, len-1, list)
              end
          end
          update_routing_table(routes, len-1, new_node_hex, current)
      else
          routes
      end
  end

  defp self_routing_table(index, len, routes, current) do
      if index > 0  do
           new_node_id = generate_node_name(index)
           new_node_hex = Integer.to_string(new_node_id, 16)
           routes = update_routing_table(routes, len, new_node_hex, current)
           self_routing_table(index-1, len, routes, current)
      else
          routes
      end
  end

  def generate_node_name(index) do
      hash = Base.encode16(:crypto.hash(:md5, Integer.to_string(index)))
      node_id = String.to_integer(hash,16)
  end

  defp leaf_plus_util(index, current_node_id, list) do
    if index > 0 do
        new_node_id = generate_node_name(index)
        newlist = list
        if(current_node_id < new_node_id ) do
            if Kernel.length(newlist) > 15 do
                newlist = List.replace_at(newlist, 15, new_node_id)
            else
                newlist = newlist ++ [new_node_id]
            end
        end
        leaf_plus_util(index-1, current_node_id, newlist)
    else
        list
    end
end

  defp leaf_minus_util(index, current_node_id, list) do
      if index > 0 do
          new_node_id = generate_node_name(index)
          new_list = list
          if(current_node_id > new_node_id ) do
              if Kernel.length(new_list) > 15 do
                  new_list = List.replace_at(new_list, 0, new_node_id)
              else
                  new_list = new_list ++ [new_node_id]
              end
          end
          leaf_minus_util(index-1, current_node_id, new_list)
      else
          list
      end
  end

  def actor_generation(index, total_nodes, routing_table) do
      if index <= total_nodes do
          node_id = generate_node_name(index)
          new_node_name = String.to_atom("node#{node_id}")
          leaf_minus = leaf_minus_util(index-1,node_id, []) 
          leaf_plus = leaf_plus_util(index-1,node_id, []) 
          leaf_minus = Enum.sort(leaf_minus)
          leaf_plus = Enum.sort(leaf_plus)
          routing_table_length = Kernel.length(routing_table)
          route_table = self_routing_table(index-1, routing_table_length, routing_table, index)
          {:ok, pid} = GenServer.start_link(PastryNode, [index, 1, leaf_minus, leaf_plus, route_table, []] , name: new_node_name)
          :global.register_name(new_node_name,pid)
          node_arrival_message(index-1, node_id)
          actor_generation(index+1, total_nodes, routing_table)
      end
  end

  def node_arrival_message(index, new_node_id) do
      if index > 0 do
          node_id = generate_node_name(index)
          new_node_name = String.to_atom("node#{node_id}")
          PastryNode.make_pastry(:global.whereis_name(new_node_name), node_id, new_node_id)
          node_arrival_message(index-1, new_node_id)
      end
  end

  def looping_function(num_nodes, num_of_requests) do
      if num_of_requests > 0 do
          initialize_message(num_nodes, num_nodes)
          :timer.sleep 1000
          looping_function(num_nodes, num_of_requests-1)
      end
  end

  def routing_tableinit(num, const_row, matrix) do 
      if num > 1 do
          new_row = const_row ++ matrix 
          routing_tableinit(num-1, const_row, new_row)
      else
          matrix
      end
  end

 def initialize_message(current_node_index, total_nodes) do
      if current_node_index > 0 do
          node_id = PastryNode.generate_node_name(current_node_index)
          new_node_name = String.to_atom("node#{node_id}")
          PastryNode.start_message(:global.whereis_name(new_node_name), total_nodes, -1, 0)
          initialize_message(current_node_index-1, total_nodes)
      end
 end

  def continue_loop() do
      :timer.sleep 10000
      supervisor_node_name = String.to_atom("supervisor")
      SupervisorNode.track(:global.whereis_name(supervisor_node_name))
  end
end

defmodule Project3 do
def main(args) do
  num_nodes = Enum.at(args,0) |> String.to_integer
  num_of_requests = Enum.at(args,1) |> String.to_integer
  rows = 32
  const_row = [[-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]] 
  routing_table = PastryNode.routing_tableinit(rows, const_row, const_row)
  supervisor_node_name = String.to_atom("supervisor")
  {:ok, pid} = GenServer.start_link(SupervisorNode, [0, num_nodes * num_of_requests] , name: supervisor_node_name)
  :global.register_name(supervisor_node_name, pid)
  PastryNode.actor_generation(1, num_nodes, routing_table)
  PastryNode.looping_function(num_nodes, num_of_requests)
  IO.puts "Average Hops"
  PastryNode.continue_loop()
end
end