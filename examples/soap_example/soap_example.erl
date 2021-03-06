%%% a simple example of the use of erlsom.
%%%
-module(soap_example).

%% user interface
-export([run/0]).

%% define records (generated by writeHrl)
-record('in:arguments', {anyAttribs, values, precision}).
-record('out:resultType', {anyAttribs, result}).
-record('out:resultType-error', {anyAttribs, error}).
-record('out:resultType-okResult', {anyAttribs, value}).
-record('out:errorType', {anyAttribs, errorCode, errorDescription}).

-record('sp:UpgradeType', {anyAttribs, 'SupportedEnvelope'}).
-record('sp:SupportedEnvType', {anyAttribs, 'qname'}).
-record('sp:NotUnderstoodType', {anyAttribs, 'qname'}).
-record('sp:detail', {anyAttribs, choice}).
-record('sp:subcode', {anyAttribs, 'Value', 'Subcode'}).
-record('sp:faultcode', {anyAttribs, 'Value', 'Subcode'}).
-record('sp:reasontext', {anyAttribs, 'xml:lang', '#text'}).
-record('sp:faultreason', {anyAttribs, 'Text'}).
-record('sp:Fault', {anyAttribs, 'Code', 'Reason', 'Node', 'Role', 'Detail'}).
-record('sp:Body', {anyAttribs, choice}).
-record('sp:Header', {anyAttribs, choice}).
-record('sp:Envelope', {anyAttribs, 'Header', 'Body'}).

run() ->
  {ModelIn, ModelOut} = compileXSDs(),

  %% parse xml
  Xml = filename:join([codeDir(), "example_in.xml"]),
  Result = case erlsom:scan_file(Xml, ModelIn) of
             {ok, #'sp:Envelope'{'Body' = #'sp:Body'{choice = Content}}, _} ->
               processContent(Content);
             {error, _} ->
               soapError("Sender", "Incorrect message")
           end,

  %% add envelope
  Response = #'sp:Envelope'{'Body' = #'sp:Body'{choice = Result}},
  %% generate xml.
  erlsom:write(Response, ModelOut).


processContent(Content) ->
  %% do something with the content
  case Content of
    [#'in:arguments'{values = undefined}] ->
      soapError("sp:Sender", "No arguments provided");
    [#'in:arguments'{values = List, precision = Precision}] ->
      Result = #'out:resultType-okResult'{value = calcAverage(List, Precision)},
      [#'out:resultType'{result=Result}];
    _ ->
      soapError("sp:Sender", "Unexpected error")
  end.


soapError(Code, Reason) ->
  FaultCode = #'sp:faultcode'{'Value' = Code},
  ReasonRec = #'sp:faultreason'{'Text' = [#'sp:reasontext'{'xml:lang' = "EN", '#text' = Reason}]},
  [#'sp:Fault'{'Code' = FaultCode, 'Reason' = ReasonRec}].


compileXSDs() ->
  EnvelopeXsd = filename:join([codeDir(), "soap-envelope.xsd"]),
  BodyXsd = filename:join([codeDir(), "example_in.xsd"]),
  ResultXsd = filename:join([codeDir(), "example_out.xsd"]),
  {ok, SoapModel} = erlsom:compile_xsd_file(EnvelopeXsd, [{prefix, "sp"}]),
  {ok, ModelIn} = erlsom:add_xsd_file(BodyXsd, [{prefix, "in"}], SoapModel),
  {ok, ModelOut} = erlsom:add_xsd_file(ResultXsd, [{prefix, "out"}], SoapModel),
  {ModelIn, ModelOut}.

calcAverage(List, Precision) ->
  calcAverage(List, Precision, 0, 0).
calcAverage([], Precision, Acc, NrOfElements) ->
  lists:flatten(io_lib:format("~.*f", [Precision, Acc/NrOfElements]));
calcAverage([Head|Tail], Precision, Acc, NrOfElements) ->
  calcAverage(Tail, Precision, Acc + Head, NrOfElements + 1).

%% this is just to make it easier to test this little example
codeDir() -> filename:dirname(code:which(?MODULE)).
